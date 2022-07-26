module main

struct Parser {
	pub:
		runtime &ViperRuntime
		filename string
		input string
	mut:
		current_input string
		pos int = -1
		line int = 1
		col int
		ch u8
		prev_ch u8
		next_ch u8
}

fn new_parser(filename string, input string, runtime ViperRuntime) Parser {
	mut p := Parser {
		filename: filename,
		current_input: input,
		input: input,
		runtime: &runtime,
	}

	p.skip(1)

	return p
}

fn (mut p Parser) parse(variables map[string]string) (string, []IError) {
	mut errors := []IError{}
	mut value := []u8{}

	for p.ch != `\0` {
		if p.ch == `{` {
			if p.next_ch == `[` {
				value << p.collect_block(variables, mut errors) or {
					errors << err
					continue
				}
			} else {
				value << p.collect_var(variables) or {
					errors << err
					continue
				}
			}
		}

		value << p.ch
		p.skip(1)
	}

	return value.bytestr(), errors
}

fn (mut p Parser) collect_block(variables map[string]string, mut errors []IError) ?[]u8 {
	mut args := []u8{}
	mut i := 1

	mut line := p.line
	mut col := p.col
	mut size := 0

	size += p.skip(2)
	size += p.skip_whitespace()
	name := p.collect_id()
	size += name.len
	noerror := name[0] == `.`
	tag_name := if noerror { name[1..] } else { name }

	for p.ch != `\0` {
		size += p.skip_whitespace()
		if p.ch == `{` && p.next_ch == `[` {
			i += 1
		} else if p.ch == `]` && p.next_ch == `}` {
			i -= 1
			if i <= 0 {
				break
			}
		}
		args << p.ch
		size += p.skip(1)
	}
	size += p.skip(2)

	if tag_name.bytestr() !in p.runtime.tags {
		if noerror {
			return []u8{}
		} else {
			return IError(TagError{
				filename: p.filename,
				message: "Unknown tag ${tag_name.bytestr()}",
				lines: p.input.split("\n"),
				line: line,
				col: col,
				size: size
			})
		}
	}

	block_tag := p.runtime.tags[tag_name.bytestr()]

	line = p.line
	col = p.col

	mut value := if block_tag.self_closing {
		""
	} else {
		p.collect_end_block(tag_name).bytestr()
	}
	for plugin in p.runtime.plugins {
		value = plugin.before_block_call(block_tag, args.bytestr(), value, variables, p)
	}
	value = block_tag.handle(
		args.bytestr(),
		value
	)
	for plugin in p.runtime.plugins {
		value = plugin.after_block_call(block_tag, args.bytestr(), value, variables, p)
	}
	
	mut content_parser := Parser {
		filename: p.filename,
		current_input: value,
		input: p.input,
		runtime: p.runtime,
		line: line,
		col: col,
	}
	content_parser.skip(1)

	parsed, errs := content_parser.parse(variables)
	errors << errs

	return parsed.bytes()
}

fn (mut p Parser) collect_end_block(open_block_name []u8) []u8 {
	mut value := []u8{}
	mut i := 0

	for p.ch != `\0` {
		if p.ch == `{` && p.next_ch == `[` {
			p.skip(2)
			skipped := p.skip_whitespace()
			name := p.collect_id()
			tag_name := if name[0] == `.` { name[1..] } else { name }
			if tag_name.bytestr() == "end" + open_block_name.bytestr() || 
				tag_name.bytestr() == ".end" + open_block_name.bytestr() {
				i -= 1
				if i <= 0 {
					p.skip_whitespace()
					p.skip(2)
					break
				}
			} else if tag_name == open_block_name {
				i += 1
			}
			p.skip(-skipped - name.len - 2)
		}

		value << p.ch
		p.skip(1)
	}

	return value
}

fn (mut p Parser) collect_var(variables map[string]string) ?[]u8 {
	mut value := []u8{}
	mut i := 1
	
	mut line := p.line
	mut col := p.col
	mut size := 0

	col += p.skip(1)
	col += p.skip_whitespace()
	for p.ch != `\0` {
		skipped_whitespace := p.skip_whitespace()
		if p.ch == `{` {
			i += 1
		} else if p.ch == `}` {
			i -= 1
			if i <= 0 {
				break
			}
		}
		value << p.ch
		size += p.skip(1) + skipped_whitespace
	}
	p.skip(1)

	noerror := value[0] == `.`
	var := if noerror { value[1..] } else { value }

	if var.bytestr() !in variables {
		if noerror {
			return []u8{}
		} else {
			return IError(VarError{
				filename: p.filename,
				message: "Unknown variable ${var.bytestr()}",
				lines: p.input.split("\n"),
				line: line,
				col: col,
				size: size
			})
		}
	}

	return variables[var.bytestr()].bytes()
}

fn (mut p Parser) collect_id() []u8 {
	mut value := []u8{}

	if p.ch == `.` {
		value << p.ch
		p.skip(1)
	}

	for p.ch.is_alnum() || p.ch == `_` {
		value << p.ch
		p.skip(1)
	}

	return value
}

fn (mut p Parser) skip(size int) int {
	p.pos += size

	p.prev_ch = p.current_input[p.pos - 1] or { `\0` }
	p.ch = p.current_input[p.pos] or { `\0` }
	p.next_ch = p.current_input[p.pos + 1] or { `\0` }

	if p.ch == `\n` {
		p.line += 1
		p.col = 0
	} else {
		p.col += 1
	}

	return size
}

fn (mut p Parser) skip_whitespace() int {
	mut skipped := 0

	for p.ch.is_space() {
		p.skip(1)
		skipped += 1
	}

	return skipped
}
