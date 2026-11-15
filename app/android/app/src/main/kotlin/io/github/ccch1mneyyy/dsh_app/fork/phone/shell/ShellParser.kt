package io.github.ccch1mneyyy.dsh_app.phone

/** 一棵已经解析好的命令树；执行前会由 [ForkShellCompiler] 重新生成规范命令。 */
internal sealed class ForkNode

internal data class ForkList(
    val first: ForkNode,
    val rest: List<Pair<String, ForkNode>>,
) : ForkNode()

internal data class ForkPipeline(val commands: List<ForkCommand>) : ForkNode()

internal data class ForkCommand(
    val argv: List<String>,
    val redirects: List<ForkRedirect>,
) : ForkNode() {
    val name: String get() = argv.firstOrNull().orEmpty()
}

internal data class ForkRedirect(
    /** `>`, `>>`, `<`, `&>`；文件描述符复制是 `dup`。 */
    val op: String,
    val target: String?,
    val fd: String? = null,
)

/**
 * 递归下降解析。
 *
 * 语法只覆盖进阶模式需要的东西：命令、管道、`;`/`&&`/`||`、输出/输入重定向。
 * 单 `&`（后台）、子 shell、here-doc、进程替换、`|&` 都会在词法或这里被拒绝。
 */
internal object ForkParser {
    fun parse(tokens: List<ForkToken>): ForkNode {
        val p = Cursor(tokens)
        val node = parseList(p)
        if (!p.done()) throw ForkSyntaxException("命令在 ${p.peek()?.let(::render)} 附近不完整。")
        return node
    }

    private fun parseList(p: Cursor): ForkNode {
        val first = parsePipeline(p)
        val rest = ArrayList<Pair<String, ForkNode>>()
        while (true) {
            val op = when (val t = p.peek()) {
                is ForkToken.Op -> t.op
                else -> break
            }
            if (op != ";" && op != "&&" && op != "||" && op != "&") break
            p.next()
            if (op == "&") throw ForkSyntaxException("后台执行（&）不在进阶模式的支持范围内。")
            // `a;` / `a &&` 末尾的空段直接忽略；`a && ; b` 这种由 parsePipeline 报错。
            if (p.done() || (p.peek() as? ForkToken.Op)?.op == ";") continue
            rest.add(op to parsePipeline(p))
        }
        return ForkList(first, rest)
    }

    private fun parsePipeline(p: Cursor): ForkNode {
        val commands = arrayListOf(parseCommand(p))
        while ((p.peek() as? ForkToken.Op)?.op == "|") {
            p.next()
            commands.add(parseCommand(p))
        }
        return ForkPipeline(commands)
    }

    private fun parseCommand(p: Cursor): ForkCommand {
        val argv = ArrayList<String>()
        val redirects = ArrayList<ForkRedirect>()
        while (true) {
            when (val t = p.peek() ?: break) {
                is ForkToken.Word -> {
                    p.next()
                    argv.add(t.text)
                }
                is ForkToken.Op -> {
                    val spec = parseRedirect(t.op) ?: break
                    p.next()
                    if (spec.first == "dup") {
                        redirects.add(ForkRedirect("dup", spec.second, spec.third))
                    } else {
                        val target = p.next() as? ForkToken.Word
                            ?: throw ForkSyntaxException("「${t.op}」后面要跟一个文件名。")
                        redirects.add(ForkRedirect(spec.first, target.text, spec.third))
                    }
                }
            }
        }
        if (argv.isEmpty() && redirects.isEmpty()) throw ForkSyntaxException("空命令。")
        return ForkCommand(argv, redirects)
    }

    /** 返回 (op, targetForDup, fd)；不是重定向返回 null。 */
    private fun parseRedirect(op: String): Triple<String, String?, String?>? {
        Regex("""^(\d*)(>>|>|<|&>)$""").matchEntire(op)?.let { m ->
            return Triple(m.groupValues[2], null, m.groupValues[1].ifEmpty { null })
        }
        Regex("""^(\d*)>&(\d+|-)$""").matchEntire(op)?.let { m ->
            return Triple("dup", m.groupValues[2], m.groupValues[1].ifEmpty { null })
        }
        return null
    }

    private fun render(t: ForkToken): String = when (t) {
        is ForkToken.Word -> "「${t.text}」"
        is ForkToken.Op -> "「${t.op}」"
    }

    private class Cursor(private val tokens: List<ForkToken>) {
        private var at = 0
        fun done(): Boolean = at >= tokens.size
        fun peek(): ForkToken? = if (done()) null else tokens[at]
        fun next(): ForkToken? = if (done()) null else tokens[at++]
    }
}

/** 把解析树重新生成一条命令：每个参数单独加引号，原始字符串里的注入点不会被带到执行层。 */
internal object ForkShellCompiler {
    fun compile(node: ForkNode): String = when (node) {
        is ForkList -> buildString {
            append(compile(node.first))
            for ((op, child) in node.rest) {
                append(' ').append(op).append(' ')
                append(compile(child))
            }
        }
        is ForkPipeline -> node.commands.joinToString(" | ") { compile(it) }
        is ForkCommand -> compileCommand(node)
    }

    private fun compileCommand(cmd: ForkCommand): String {
        val parts = ArrayList<String>()
        parts.addAll(cmd.argv.map(::quote))
        for (r in cmd.redirects) {
            when (r.op) {
                "dup" -> parts.add("${r.fd ?: ""}>&${r.target}")
                else -> parts.add("${r.fd ?: ""}${r.op}${quote(r.target.orEmpty())}")
            }
        }
        return parts.joinToString(" ")
    }

    private fun quote(s: String): String {
        if (s.isEmpty()) return "''"
        // 普通参数和只读命令的通配符保持原样；其余全部单引号包起来。
        if (s.all { it.isLetterOrDigit() || it in "_@%+=:,./-" }) return s
        val special = setOf(' ', '\t', '\n', ';', '&', '|', '<', '>', '(', ')', '$', '\'', '"', '`', '\\')
        if (s.any { it == '*' || it == '?' } && s.none { it in special }) return s
        return "'" + s.replace("'", "'\\''") + "'"
    }
}
