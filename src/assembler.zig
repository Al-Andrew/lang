const std = @import("std");
const lang = @import("lang.zig");

const Self = @This();


text : []const u8 = undefined,
current_idx : usize = 0,
alloc : std.mem.Allocator = undefined,
lable_table : std.StringHashMap(u64) = undefined,
jump_table : std.AutoHashMap(u64, []const u8) = undefined,

fn is_whitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\t';
}

fn skip_whitespace(self: *Self) void {
    while (self.current_idx < self.text.len) {
        const c = self.text[self.current_idx];
        if (!is_whitespace(c)) {
            break;
        }
        self.current_idx += 1;
    }
}

fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn is_ident_char(c: u8) bool {
    return is_alpha(c) or is_digit(c) or c == '_';
}

fn lex_ident(self: *Self) ![]const u8 {
    self.skip_whitespace();

    const start = self.current_idx;
    while (self.current_idx < self.text.len) {
        const c = self.text[self.current_idx];

        // identifier can only start with a letter
        if (self.current_idx == start and !is_alpha(c)) {
            return error.IdentifierStartNotFound;
        }
        // then move untill not is_ident_char or :
        if (!(is_ident_char(c) or c == ':')) {
            break;
        }
        self.current_idx += 1;
    }
    return self.text[start..self.current_idx];
}

fn ident_to_opcode(ident: []const u8) !lang.Instruction.Type {
    const len = @typeInfo(lang.Instruction.Type).@"Enum".fields.len;
    inline for(0..len) |i| {
        const field = @typeInfo(lang.Instruction.Type).@"Enum".fields[i];
        if (std.mem.eql(u8, ident, field.name)) {
            return @enumFromInt(field.value);
        }
    }
    return error.UnknownOpcode;
}

test "ident_to_opcode" {
    const opcode = try ident_to_opcode("movri");
    try std.testing.expect(opcode == lang.Instruction.Type.movri);
}

fn lex_reg(self: *Self) !u64 {
    const ident = try self.lex_ident();
    if (ident.len < 2 or ident[0] != 'r') {
        return error.NotARegister;
    }
    var reg: u64 = 0;
    for (ident[1..]) |c| {
        if (!is_digit(c)) {
            return error.RegisterNotANumber;
        }
        reg = reg * 10 + (c - '0');
    }

    if(reg > 31) {
        return error.InvalidRegisterValue;
    }

    return reg;
}

test "lex_reg" {
    var self = Self{
        .text = "r12",
        .current_idx = 0,
        .alloc = std.heap.page_allocator,
    };
    const reg = try self.lex_reg();
    try std.testing.expect(reg == 12);
}

fn lex_imm(self: *Self) !i64 {
    // TODO: hex, octal, binary
    self.skip_whitespace();

    const start = self.current_idx;
    while (self.current_idx < self.text.len) {
        const c = self.text[self.current_idx];

        if(self.current_idx == start and (c == '-' or c == '+')) {
            self.current_idx += 1;
            continue;
        }

        if (!is_digit(c)) {
            break;
        }
        self.current_idx += 1;
    }

    if (self.current_idx == start) {
        return error.NoDigitsFound;
    }

    const imm_str = self.text[start..self.current_idx];
    const imm = try std.fmt.parseInt(i64, imm_str, 10);
    return imm;
}

test "lex_imm" {
    var self = Self{
        .text = "123",
        .current_idx = 0,
        .alloc = std.heap.page_allocator,
    };
    const imm = try self.lex_imm();
    try std.testing.expect(imm == 123);
}

fn lex_label_or_imm(self: *Self, current_instruction_offset: u64) !i64 {
    self.skip_whitespace();

    if (self.current_idx >= self.text.len) {
        return error.ExpectedLabelOrImmNotFound;
    }

    if(self.text[self.current_idx] == ':') {
        self.current_idx += 1;
        const label = try self.lex_ident();
        try self.jump_table.put(current_instruction_offset, label);
        return 0xdeadbeef;
    } else {
        return try self.lex_imm();
    }
}

fn expect_char(self: *Self, c: u8) !void {
    self.skip_whitespace();
    if (self.current_idx >= self.text.len) {
        return error.ExpectedCharNotFound;
    }
    if (self.text[self.current_idx] != c) {
        return error.ExpectedCharNotFound;
    }
    self.current_idx += 1;
}

fn fixup_jumps(self: *Self, instructions: []lang.Instruction) !void {
    var jt = self.jump_table.iterator();
    while (jt.next()) |jt_entry| {
        const jump_instruction_offset = jt_entry.key_ptr.*;
        const jump_target_label = jt_entry.value_ptr.*;
        const jump_target = self.lable_table.get(jump_target_label);
        if (jump_target == null) {
            return error.LabelNotFound;
        }
        std.debug.print("Fixing up jump label: {s} -> {d} for {d}\n", .{jump_target_label, jump_target.?, jump_instruction_offset});
        instructions[jump_instruction_offset].op2 = @intCast(jump_target.?);
    }
}

pub fn assemble_text(alloc: std.mem.Allocator, text: []const u8) ![]lang.Instruction {
    
    var self = Self{
        .text = text,
        .current_idx = 0,
        .alloc = alloc,
        .lable_table = std.StringHashMap(u64).init(alloc),
        .jump_table = std.AutoHashMap(u64, []const u8).init(alloc),
    };

    var instructions = std.ArrayList(lang.Instruction).init(alloc);

    while(self.current_idx < text.len) {
        const ident = try self.lex_ident();
        if (ident[ident.len - 1] == ':') {
            const label = ident[0..ident.len - 1]; // remove :
            try self.lable_table.put(label, instructions.items.len);
            continue;
        }

        const opcode = try ident_to_opcode(ident);
        switch(opcode) {
            lang.Instruction.Type.movri => {
                const reg = try self.lex_reg();
                try self.expect_char(',');
                const imm = try self.lex_imm();
                const instr = lang.Instruction.movri(reg, imm);
                try instructions.append(instr);
            },
            lang.Instruction.Type.movrr => {
                const dst = try self.lex_reg();
                try self.expect_char(',');
                const src = try self.lex_reg();
                const instr = lang.Instruction.movrr(dst, src);
                try instructions.append(instr);
            },
            lang.Instruction.Type.addrrr => {
                const dst = try self.lex_reg();
                try self.expect_char(',');
                const src1 = try self.lex_reg();
                try self.expect_char(',');
                const src2 = try self.lex_reg();
                const instr = lang.Instruction.addrrr(dst, src1, src2);
                try instructions.append(instr);
            },
            lang.Instruction.Type.addrri => {
                const dst = try self.lex_reg();
                try self.expect_char(',');
                const src = try self.lex_reg();
                try self.expect_char(',');
                const imm = try self.lex_imm();
                const instr = lang.Instruction.addrri(dst, src, imm);
                try instructions.append(instr);
            },
            lang.Instruction.Type.cmpri => {
                const dst = try self.lex_reg();
                try self.expect_char(',');
                const src = try self.lex_reg();
                try self.expect_char(',');
                const imm = try self.lex_imm();
                const instr = lang.Instruction.cmpri(dst, src, imm);
                try instructions.append(instr);
            },
            lang.Instruction.Type.jleri => {
                const reg = try self.lex_reg();
                try self.expect_char(',');
                // NOTE: weird thing here with the label, consider making another instruction
                const offset = try self.lex_label_or_imm(instructions.items.len);
                const instr: lang.Instruction = lang.Instruction.jleri(reg, offset);
                try instructions.append(instr);
            },
            lang.Instruction.Type.dbgprintr => {
                const reg = try self.lex_reg();
                const instr = lang.Instruction.dbgprintr(reg);
                try instructions.append(instr);
            },
        }

        self.skip_whitespace();
    }

    try self.fixup_jumps(instructions.items);

    return instructions.items;
}

test "movri" {
    const text = "movri r0, 123";
    const instructions = try assemble_text(std.heap.page_allocator, text);
    try std.testing.expect(instructions.len == 1);
    try std.testing.expect(instructions[0].opcode == lang.Instruction.Type.movri);
    try std.testing.expect(instructions[0].op1 == 0);
    try std.testing.expect(instructions[0].op2 == 123);
}

test "simple fib" {

    const text = 
    \\movri r0, 0
    \\movri r1, 1
    \\movri r3, 0
    \\loop:
    \\addrrr r2, r0, r1
    \\movrr r0, r1
    \\movrr r1, r2
    \\addrri r3, r3, 1
    \\cmpri r4, r3, 10
    \\dbgprintr r0
    \\jleri r4, :loop
    \\
    ;
    const program = try assemble_text(std.heap.page_allocator, text);
    var vm = lang.VM.init();
    try vm.run_program(program);

    try std.testing.expect(vm.registers[0] == 55);
}