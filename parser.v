module main

pub struct Parser {
	pub mut:
		context Context
		tags map[string]Tag
	pub:
		input string
	mut:
		original_input string
		pos int = -1
		line int = 1
		col int
		ch u8
		prev_ch u8
		next_ch u8
}

pub fn new(input string, context Context, tags ...Tag) Parser {
	mut tags_map := map[string]Tag{}
	for tag in tags {
		tags_map[tag.name] = tag
	}

	mut p := Parser {
		input: input,
		original_input: input,
		tags: tags_map
	}

	p.skip(1)

	return p
}

pub fn (mut p Parser) parse() string {
	mut value := []u8{}

	for p.ch != `\0` {
		if p.ch == `{` {
			if p.next_ch == `[` {
				value << p.collect_block()
			} else {
				value << p.collect_var()
			}
		}

		value << p.ch
		p.skip(1)
	}

	return value.bytestr()
}

fn (mut p Parser) collect_block() []u8 {
	mut value := []u8{}
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
		value << p.ch
		size += p.skip(1)
	}
	size += p.skip(2)

	if tag_name.bytestr() !in p.tags {
		if noerror {
			return []u8{}
		} else {
			panic_error(
				"TagError", 
				"Unknown tag ${tag_name.bytestr()} at line ${line}, col ${col}",
				p.original_input.split("\n"),
				line,
				col,
				size
			)
		}
	}

	block_tag := p.tags[tag_name.bytestr()]

	line = p.line
	col = p.col
	content := block_tag.handle(
		value.bytestr(), 
		if block_tag.self_closing {
			""
		} else {
			p.collect_end_block(tag_name).bytestr()
		}
	)
	
	mut content_parser := new(content, p.context, ...p.tags.values())
	content_parser.original_input = p.original_input
	content_parser.line = line
	content_parser.col = col
	return content_parser.parse().bytes()
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

fn (mut p Parser) collect_var() []u8 {
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

	if var.bytestr() !in p.context.data {
		if noerror {
			return []u8{}
		} else {
			panic_error(
				"VarError", 
				"Unknown variable ${var.bytestr()} at line ${p.line}, col ${p.col}",
				p.original_input.split("\n"),
				line,
				col,
				size
			)
		}
	}

	return p.context.data[var.bytestr()].bytes()
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

	p.prev_ch = p.input[p.pos - 1] or { `\0` }
	p.ch = p.input[p.pos] or { `\0` }
	p.next_ch = p.input[p.pos + 1] or { `\0` }

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
