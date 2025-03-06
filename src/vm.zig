const std = @import("std");
const lang = @import("lang.zig");

const Self = @This();

registers : [32]i64 = undefined,


pub fn init() Self {
    var vm = Self{
        .registers = undefined,
    };
    @memset(&vm.registers, 0);
    return vm;
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
    var vm = Self.init();
    try vm.run_program(&program);
    const expected = 610;
    const actual = vm.registers[0];
    try std.testing.expectEqual(expected, actual);
}