// 反编译验证脚本：导出前 3 个函数的 C 伪代码
// 用途：验证自编译的 mac_arm_64 反编译器引擎是否真正工作
import ghidra.app.decompiler.*;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;

public class DecompileProbe extends GhidraScript {
    public void run() throws Exception {
        DecompInterface ifc = new DecompInterface();
        ifc.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();
        int n = 0;
        int fail = 0;
        for (Function f : fm.getFunctions(true)) {
            DecompileResults res = ifc.decompileFunction(f, 60, monitor);
            if (res.decompileCompleted()) {
                String c = res.getDecompiledFunction().getC();
                println("=== FUNCTION: " + f.getName() + " ===");
                println(c.length() > 600 ? c.substring(0, 600) : c);
                n++;
            } else {
                fail++;
                println("FAIL " + f.getName() + ": " + res.getErrorMessage());
            }
            if (n >= 3) break;
        }
        println("PROBE_RESULT decompiled=" + n + " failed=" + fail);
    }
}
