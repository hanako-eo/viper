module main

pub struct Parser {
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

pub fn new(input string) Parser {
	mut p := Parser {
		input: input
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

fn (mut p Parser) skip_whitespace() {
	for p.ch.is_space() {
		p.skip(1)
	}
}
