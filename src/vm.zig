const std = @import("std");
const lang = @import("lang.zig");

const Self = @This();

const STACK_SIZE: usize = 1024 * 1024; // 1MB

registers : [32]i64 = undefined, // TODO: allog special names for important registers, 31-SP
stack: []u8 = undefined,
alloc: std.mem.Allocator = undefined,

pub fn init(alloc: std.mem.Allocator) !Self {
    var vm = Self{
        .registers = undefined,
        .stack = try alloc.alloc(u8, STACK_SIZE),
        .alloc = alloc,
    };
    @memset(&vm.registers, 0);
    return vm;
}

pub fn deinit(self: *Self) void {
    self.alloc.free(self.stack);
}

pub fn run_program(self: *Self, program: []const lang.Instruction) !void {
    var pc: u64 = 0;
    while (pc < program.len) {
        const instr = program[pc];
        pc += 1;
        switch (instr.opcode) {
            lang.Instruction.Type.movri => {
                self.registers[@intCast(instr.op1)] = instr.op2;
            },
            lang.Instruction.Type.movrr => {
                self.registers[@intCast(instr.op1)] = self.registers[@intCast(instr.op2)];
            },
            lang.Instruction.Type.pushi => {
                const addr = self.registers[31];
                self.stack[@intCast(addr)] = @intCast(instr.op1 & 0xFF);
                self.stack[@intCast(addr + 1)] = @intCast((instr.op1 >> 8)  & 0xFF);
                self.stack[@intCast(addr + 2)] = @intCast((instr.op1 >> 16) & 0xFF);
                self.stack[@intCast(addr + 3)] = @intCast((instr.op1 >> 24) & 0xFF);
                self.stack[@intCast(addr + 4)] = @intCast((instr.op1 >> 32) & 0xFF);
                self.stack[@intCast(addr + 5)] = @intCast((instr.op1 >> 40) & 0xFF);
                self.stack[@intCast(addr + 6)] = @intCast((instr.op1 >> 48) & 0xFF);
                self.stack[@intCast(addr + 7)] = @intCast((instr.op1 >> 56) & 0xFF);

                self.registers[31] += 8;
            },
            lang.Instruction.Type.pushr => {
                const addr = self.registers[31];
                self.stack[@intCast(addr)] = @intCast(self.registers[@intCast(instr.op1)] & 0xFF);
                self.stack[@intCast(addr + 1)] = @intCast((self.registers[@intCast(instr.op1)] >> 8) & 0xFF);
                self.stack[@intCast(addr + 2)] = @intCast((self.registers[@intCast(instr.op1)] >> 16) & 0xFF);
                self.stack[@intCast(addr + 3)] = @intCast((self.registers[@intCast(instr.op1)] >> 24) & 0xFF);
                self.stack[@intCast(addr + 4)] = @intCast((self.registers[@intCast(instr.op1)] >> 32) & 0xFF);
                self.stack[@intCast(addr + 5)] = @intCast((self.registers[@intCast(instr.op1)] >> 40) & 0xFF);
                self.stack[@intCast(addr + 6)] = @intCast((self.registers[@intCast(instr.op1)] >> 48) & 0xFF);
                self.stack[@intCast(addr + 7)] = @intCast((self.registers[@intCast(instr.op1)] >> 56) & 0xFF);

                self.registers[31] += 8;
            },
            lang.Instruction.Type.popr => {
                self.registers[31] -= 8;
                const addr = self.registers[31];
                self.registers[@intCast(instr.op1)] = @as(i64,self.stack[@intCast(addr)])
                    | (@as(i64, self.stack[@intCast(addr + 1)]) << 8)
                    | (@as(i64, self.stack[@intCast(addr + 2)]) << 16)
                    | (@as(i64, self.stack[@intCast(addr + 3)]) << 24)
                    | (@as(i64, self.stack[@intCast(addr + 4)]) << 32)
                    | (@as(i64, self.stack[@intCast(addr + 5)]) << 40)
                    | (@as(i64, self.stack[@intCast(addr + 6)]) << 48)
                    | (@as(i64, self.stack[@intCast(addr + 7)]) << 56);
            },
            lang.Instruction.Type.addrrr => {
                self.registers[@intCast(instr.op1)] = self.registers[@intCast(instr.op2)] + self.registers[@intCast(instr.op3)];
            },
            lang.Instruction.Type.addrri => {
                self.registers[@intCast(instr.op1)] = self.registers[@intCast(instr.op2)] + instr.op3;
            },
            lang.Instruction.Type.cmpri => {
                self.registers[@intCast(instr.op1)] = self.registers[@intCast(instr.op2)] - instr.op3;
            },
            lang.Instruction.Type.jleri => {
                if (self.registers[@intCast(instr.op1)] < 0) {
                    pc = @intCast(instr.op2);
                }
            },
            lang.Instruction.Type.dbgprintr => {
                std.debug.print("Register {d}: {d}\n", .{instr.op1, self.registers[@intCast(instr.op1)]});
            },
        }
    }
}


test "simple fib" {
    const program = [_]lang.Instruction{
        lang.Instruction.movri(0, 0),
        lang.Instruction.movri(1, 1),
        lang.Instruction.movri(3, 0),
        lang.Instruction.addrrr(2, 0, 1),
        lang.Instruction.movrr(0, 1),
        lang.Instruction.movrr(1, 2),
        lang.Instruction.addrri(3, 3, 1),
        lang.Instruction.cmpri(4, 3, 15),
        lang.Instruction.jleri(4, 3),
        lang.Instruction.dbgprintr(0)
    };
    var vm = try Self.init(std.heap.page_allocator);
    defer vm.deinit();

    try vm.run_program(&program);
    const expected = 610;
    const actual = vm.registers[0];
    try std.testing.expectEqual(expected, actual);
}

test "push/pop" {
    const program = [_]lang.Instruction{
        lang.Instruction.pushi(1234567),
        lang.Instruction.movri(0, 31),
        lang.Instruction.pushr(0),
        lang.Instruction.popr(0),
        lang.Instruction.dbgprintr(0),
        lang.Instruction.popr(1),
        lang.Instruction.dbgprintr(1),
    };
    var vm = try Self.init(std.heap.page_allocator);
    defer vm.deinit();

    try vm.run_program(&program);
    try std.testing.expectEqual(31, vm.registers[0]);
    try std.testing.expectEqual(1234567, vm.registers[1]);
}