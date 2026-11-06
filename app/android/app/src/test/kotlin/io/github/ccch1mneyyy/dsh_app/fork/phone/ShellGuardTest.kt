package io.github.ccch1mneyyy.dsh_app.phone

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 进阶模式（SAFE）的静态判定：白名单只看段首词，所以相对路径、包装器和内嵌执行都不能漏。
 */
class ShellGuardTest {
    private val safe = ShellCommands.SAFE_DEFAULT

    private fun denied(command: String, allowed: Set<String> = safe, sdcardOn: Boolean = false): Boolean =
        ShellGuard.judge(ShellMode.SAFE, command, allowed, sdcardOn) is ShellVerdict.Deny

    private fun allowed(command: String, allowed: Set<String> = safe, sdcardOn: Boolean = false): Boolean =
        ShellGuard.judge(ShellMode.SAFE, command, allowed, sdcardOn) is ShellVerdict.Allow

    @Test
    fun `relative paths after cd cannot reach protected data`() {
        assertTrue(denied("cd /; cat data/adb/magisk.db"))
        assertTrue(denied("cd /; echo x > data/adb/magisk.db"))
        assertTrue(denied("cd /data; cat adb/magisk.db"))
        assertTrue(denied("cd /..; cat data/adb/magisk.db"))
    }

    @Test
    fun `relative redirects resolve against the tracked directory`() {
        assertTrue(denied("cd /root; echo x > ../../data/adb/x"))
        assertTrue(denied("echo x > data/adb/x"))
    }

    @Test
    fun `wrappers that run another command are refused`() {
        assertTrue(denied("env setenforce 0"))
        assertTrue(denied("nice setenforce 0"))
        assertTrue(denied("nohup setenforce 0"))
        assertTrue(denied("timeout 5 setenforce 0"))
        assertTrue(denied("busybox setenforce 0"))
    }

    @Test
    fun `embedded execution inside awk and sed is refused`() {
        assertTrue(denied("""awk 'BEGIN{system("setenforce 0")}'"""))
        assertTrue(denied("""awk '{while ((getline line) > 0) print line}' file"""))
        assertTrue(denied("""sed 's/x/setenforce 0/e' file"""))
        assertTrue(denied("""sed 's/x/y/e' file"""))
    }

    @Test
    fun `the photo album is read only in safe mode`() {
        assertTrue(allowed("ls /sdcard/DCIM", sdcardOn = true))
        assertTrue(allowed("cat /sdcard/DCIM/a.jpg", sdcardOn = true))
        assertTrue(denied("cp /sdcard/DCIM/a.jpg /sdcard/Download/", sdcardOn = true))
        assertTrue(denied("mv /sdcard/DCIM/a.jpg /sdcard/Download/", sdcardOn = true))
        assertTrue(denied("rm /sdcard/DCIM/a.jpg", sdcardOn = true))
        assertTrue(denied("sort -o /sdcard/DCIM/x /sdcard/DCIM/y", sdcardOn = true))
        assertTrue(denied("logcat -f /sdcard/DCIM/log.txt", sdcardOn = true))
        assertTrue(denied("echo x > /sdcard/DCIM/x", sdcardOn = true))
    }

    @Test
    fun `cd cannot enter the album`() {
        assertTrue(denied("cd /sdcard/DCIM; rm *", sdcardOn = true))
        assertTrue(denied("cd /sdcard/Pictures; ls", sdcardOn = true))
        assertTrue(allowed("cd /sdcard/Download; ls", sdcardOn = true))
    }

    @Test
    fun `write commands reject dot dot hops`() {
        assertTrue(denied("rm /sdcard/Download/../DCIM/a.jpg", sdcardOn = true))
        assertTrue(denied("cp /sdcard/Download/a /sdcard/Download/../x", sdcardOn = true))
    }

    @Test
    fun `cp with a -t target directory is not treated as move`() {
        assertTrue(allowed("cp -t /sdcard/Download /data/local/tmp/a", sdcardOn = true))
        assertTrue(denied("cp -t /sdcard/DCIM /data/local/tmp/a", sdcardOn = true))
    }

    @Test
    fun `the data root is closed except the app and tmp`() {
        assertTrue(denied("cat /data/deepseek/x"))
        assertTrue(denied("ls /data/misc"))
        assertTrue(allowed("ls /data/local/tmp"))
    }

    @Test
    fun `find and pm escape hatches stay closed`() {
        assertTrue(denied("find /root -name x -exec rm {} ;"))
        assertTrue(denied("pm clear com.example"))
    }

    @Test
    fun `ordinary read-only commands still pass`() {
        assertTrue(allowed("ls /sdcard/Download"))
        assertTrue(allowed("cat /sdcard/Download/notes.txt"))
        assertTrue(allowed("ps -A"))
        assertTrue(allowed("echo hello"))
        assertTrue(allowed("cd /root; cat env.sh"))
        assertTrue(allowed("grep -n foo /root/.bashrc"))
    }

    @Test
    fun `writes stay inside the allowed roots`() {
        assertTrue(allowed("cd /sdcard/Download; echo x > note.txt", sdcardOn = true))
        assertTrue(denied("cd /root; echo x > note.txt"))
        assertTrue(denied("echo x > /data/adb/x"))
    }

    @Test
    fun `full mode is not filtered`() {
        assertTrue(ShellGuard.judge(ShellMode.FULL, "env setenforce 0", emptySet()) is ShellVerdict.Allow)
    }
}
