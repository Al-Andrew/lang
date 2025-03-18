const std = @import("std");

pub const Instruction = struct {
    opcode: Type,
    op1: i64,
    op2: i64,
    op3: i64,


    pub const Type = enum {
        movri,
        movrr,
        pushi,
        pushr,
        popr,
        addrrr,
        addrri,
        cmpri,
        jleri,
        hlt,
        dbgprintr,
    };

    pub fn movri(reg: u64, imm: i64) Instruction {
        return Instruction{ .opcode = Type.movri, .op1 = @intCast(reg), .op2 = imm, .op3 = 0 };
    }

    pub fn movrr(dst: u64, src: u64) Instruction {
        return Instruction{ .opcode = Type.movrr, .op1 = @intCast(dst), .op2 = @intCast(src), .op3 = 0 };
    }

    pub fn pushi(imm: i64) Instruction {
        return Instruction{ .opcode = Type.pushi, .op1 = imm, .op2 = 0, .op3 = 0 };
    }

    pub fn pushr(reg: u64) Instruction {
        return Instruction{ .opcode = Type.pushr, .op1 = @intCast(reg), .op2 = 0, .op3 = 0 };
    }

    pub fn popr(reg: u64) Instruction {
        return Instruction{ .opcode = Type.popr, .op1 = @intCast(reg), .op2 = 0, .op3 = 0 };
    }

    pub fn addrrr(dst: u64, src1: u64, src2: u64) Instruction {
        return Instruction{ .opcode = Type.addrrr, .op1 = @intCast(dst), .op2 = @intCast(src1), .op3 = @intCast(src2) };
    }

    pub fn addrri(dst: u64, src: u64, imm: i64) Instruction {
        return Instruction{ .opcode = Type.addrri, .op1 = @intCast(dst), .op2 = @intCast(src), .op3 = imm };
    }

    pub fn cmpri(dst: u64, src: u64, imm: i64) Instruction {
        return Instruction{ .opcode = Type.cmpri, .op1 = @intCast(dst), .op2 = @intCast(src), .op3 = imm };
    }

    pub fn jleri(reg: u64, offset: i64) Instruction {
        return Instruction{ .opcode = Type.jleri, .op1 = @intCast(reg), .op2 = offset, .op3 = 0 };
    }

    pub fn hlt() Instruction {
        return Instruction{ .opcode = Type.hlt, .op1 = 0, .op2 = 0, .op3 = 0 };
    }

    pub fn dbgprintr(reg: u64) Instruction {
        return Instruction{ .opcode = Type.dbgprintr, .op1 = @intCast(reg), .op2 = 0, .op3 = 0 };
    }
};