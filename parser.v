module main

pub struct Parser {
	pub mut:
		tags map[string]Tag
	pub:
		input string
	mut:
		pos int = -1
		line int
		col int
		ch u8
		prev_ch u8
		next_ch u8
}

pub fn new(input string, tags ...Tag) Parser {
	mut tags_map := map[string]Tag{}
	for tag in tags {
		tags_map[tag.name] = tag
	}

	mut p := Parser {
		input: input,
		tags: tags_map
	}

	p.skip(2)

	return p
}

pub fn (mut p Parser) parse() string {
	mut value := [p.prev_ch]

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

	p.skip(2)
	p.skip_whitespace()
	name := p.collect_id()
	noerror := name[0] == `.`
	tag_name := if noerror { name[1..] } else { name }

	for p.ch != `\0` {
		p.skip_whitespace()
		if p.ch == `{` && p.next_ch == `[` {
			i += 1
		} else if p.ch == `]` && p.next_ch == `}` {
			i -= 1
			if i <= 0 {
				break
			}
		}
		value << p.ch
		p.skip(1)
	}
	p.skip(2)

	if tag_name.bytestr() !in p.tags {
		if noerror {
			return []u8{}
		} else {
			panic("Unknown block tag: " + tag_name.bytestr())
		}
	}

	block_tag := p.tags[tag_name.bytestr()]

	content := block_tag.handle(
		value.bytestr(), 
		if block_tag.self_closing {
			""
		} else {
			p.collect_end_block(tag_name).bytestr()
		}
	)
	
	mut content_parser := new(content)
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

	p.skip(1)
	for p.ch != `\0` {
		p.skip_whitespace()
		if p.ch == `{` {
			i += 1
		} else if p.ch == `}` {
			i -= 1
			if i <= 0 {
				break
			}
		}
		value << p.ch
		p.skip(1)
	}
	p.skip(1)

	return value
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

fn (mut p Parser) skip(size int) {
	p.pos += size

	p.prev_ch = p.input[p.pos - 1] or { `\0` }
	p.ch = p.input[p.pos] or { `\0` }
	p.next_ch = p.input[p.pos + 1] or { `\0` }

	if p.ch == `\n` {
		p.line += 1
		p.col = 1
	} else {
		p.col += 1
	}
}

fn (mut p Parser) skip_whitespace() int {
	mut skipped := 0

	for p.ch.is_space() {
		p.skip(1)
		skipped += 1
	}

	return skipped
}
