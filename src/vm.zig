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
    vm.registers[31] = @bitCast(@intFromPtr(vm.stack.ptr));
    return vm;
}

pub fn deinit(self: *Self) void {
    self.alloc.free(self.stack);
}

fn store_i64(ptr: [*]u8, value: i64) void {
    ptr[0] = @intCast(value & 0xFF);
    ptr[1] = @intCast((value >> 8)  & 0xFF);
    ptr[2] = @intCast((value >> 16) & 0xFF);
    ptr[3] = @intCast((value >> 24) & 0xFF);
    ptr[4] = @intCast((value >> 32) & 0xFF);
    ptr[5] = @intCast((value >> 40) & 0xFF);
    ptr[6] = @intCast((value >> 48) & 0xFF);
    ptr[7] = @intCast((value >> 56) & 0xFF);
}

fn read_i64(ptr: [*]u8) i64 {
    return @as(i64, ptr[0])
        | (@as(i64, ptr[1]) << 8)
        | (@as(i64, ptr[2]) << 16)
        | (@as(i64, ptr[3]) << 24)
        | (@as(i64, ptr[4]) << 32)
        | (@as(i64, ptr[5]) << 40)
        | (@as(i64, ptr[6]) << 48)
        | (@as(i64, ptr[7]) << 56);
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
                const off: usize = @bitCast(self.registers[31]);
                const addr: [*]u8 = @ptrFromInt(off);

                store_i64(addr, instr.op1);

                self.registers[31] += 8;
            },
            lang.Instruction.Type.pushr => {
                const off: usize = @bitCast(self.registers[31]);
                const addr: [*]u8 = @ptrFromInt(off);

                store_i64(addr, self.registers[@intCast(instr.op1)]);

                self.registers[31] += 8;
            },
            lang.Instruction.Type.popr => {
                self.registers[31] -= 8;
                const off: usize = @bitCast(self.registers[31]);
                const addr: [*]u8 = @ptrFromInt(off);

                self.registers[@intCast(instr.op1)] = read_i64(addr);
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