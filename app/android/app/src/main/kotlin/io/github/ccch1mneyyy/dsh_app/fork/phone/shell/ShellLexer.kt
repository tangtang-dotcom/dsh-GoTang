package io.github.ccch1mneyyy.dsh_app.phone

/** 词法单元：一个已经去掉引号的参数，或一个操作符。 */
internal sealed class ForkToken {
    data class Word(val text: String) : ForkToken()
    data class Op(val op: String) : ForkToken()
}

internal class ForkSyntaxException(message: String) : Exception(message)

/**
 * 把一行 shell 拆成词法单元。
 *
 * 关键点：引号里的字符不再被当成操作符；`&` 单独出现就是后台执行，必须拆出来；
 * `( )`、`<<`、反引号、`$` 展开一律拒绝。这个层不做任何业务判断，只保证
 * 后面的语法树看到的是真实的词和操作符。
 */
internal object ForkLexer {
    fun lex(raw: String): List<ForkToken> {
        val out = ArrayList<ForkToken>()
        val word = StringBuilder()
        var inWord = false
        var i = 0
        val n = raw.length

        fun flush() {
            if (inWord) {
                out.add(ForkToken.Word(word.toString()))
                word.setLength(0)
                inWord = false
            }
        }

        while (i < n) {
            val c = raw[i]
            when {
                c == ' ' || c == '\t' || c == '\r' -> {
                    flush()
                    i++
                }
                c == '\n' -> {
                    flush()
                    out.add(ForkToken.Op(";"))
                    i++
                }
                c == '\'' -> {
                    inWord = true
                    i++
                    val start = i
                    while (i < n && raw[i] != '\'') i++
                    if (i >= n) throw ForkSyntaxException("引号没有闭合。")
                    word.append(raw, start, i)
                    i++
                }
                c == '"' -> {
                    inWord = true
                    i++
                    var closed = false
                    while (i < n) {
                        val d = raw[i]
                        if (d == '"') {
                            closed = true
                            i++
                            break
                        }
                        if (d == '\\' && i + 1 < n) {
                            val e = raw[i + 1]
                            if (e == '"' || e == '\\' || e == '$' || e == '`') {
                                word.append(e)
                                i += 2
                                continue
                            }
                        }
                        if (d == '$') throw ForkSyntaxException("命令里有变量展开（\$），进阶模式下不允许。")
                        if (d == '`') throw ForkSyntaxException("命令里有反引号，进阶模式下不允许。")
                        word.append(d)
                        i++
                    }
                    if (!closed) throw ForkSyntaxException("双引号没有闭合。")
                }
                c == '\\' -> {
                    inWord = true
                    if (i + 1 < n) {
                        word.append(raw[i + 1])
                        i += 2
                    } else {
                        i++
                    }
                }
                c == '$' -> throw ForkSyntaxException("命令里有变量展开（\$），进阶模式下不允许。")
                c == '`' -> throw ForkSyntaxException("命令里有反引号，进阶模式下不允许。")
                c == ';' -> {
                    flush()
                    out.add(ForkToken.Op(";"))
                    i++
                }
                c == '&' -> {
                    flush()
                    when {
                        i + 1 < n && raw[i + 1] == '&' -> {
                            out.add(ForkToken.Op("&&"))
                            i += 2
                        }
                        i + 1 < n && raw[i + 1] == '>' -> {
                            out.add(ForkToken.Op("&>"))
                            i += 2
                        }
                        else -> {
                            out.add(ForkToken.Op("&"))
                            i++
                        }
                    }
                }
                c == '|' -> {
                    flush()
                    when {
                        i + 1 < n && raw[i + 1] == '|' -> {
                            out.add(ForkToken.Op("||"))
                            i += 2
                        }
                        i + 1 < n && raw[i + 1] == '&' -> throw ForkSyntaxException("`|&` 不在进阶模式的支持范围内。")
                        else -> {
                            out.add(ForkToken.Op("|"))
                            i++
                        }
                    }
                }
                c == '<' -> {
                    flush()
                    if (i + 1 < n && raw[i + 1] == '<') throw ForkSyntaxException("here-doc（<<）不在进阶模式的支持范围内。")
                    if (i + 1 < n && raw[i + 1] == '(') throw ForkSyntaxException("进程替换（<(...)）不在进阶模式的支持范围内。")
                    out.add(ForkToken.Op("<"))
                    i++
                }
                c == '>' -> {
                    val fd = word.toString().takeIf { inWord && it.isNotEmpty() && it.all { ch -> ch.isDigit() } }
                    if (fd != null) {
                        word.setLength(0)
                        inWord = false
                    }
                    flush()
                    // 2>&1 / >&2 这类文件描述符复制：不是路径，原样保留。
                    if (i + 1 < n && raw[i + 1] == '&') {
                        var j = i + 2
                        val start = j
                        while (j < n && (raw[j].isDigit() || raw[j] == '-')) j++
                        if (j > start) {
                            out.add(ForkToken.Op("${fd ?: ""}>&${raw.substring(start, j)}"))
                            i = j
                            continue
                        }
                    }
                    val op = if (i + 1 < n && raw[i + 1] == '>') ">>" else ">"
                    out.add(ForkToken.Op((fd ?: "") + op))
                    i += op.length
                }
                c == '(' || c == ')' -> throw ForkSyntaxException("子 shell 和括号分组（$c）不在进阶模式的支持范围内。")
                else -> {
                    inWord = true
                    word.append(c)
                    i++
                }
            }
        }
        flush()
        return out
    }
}
