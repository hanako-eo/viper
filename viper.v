module main

import os

pub interface ViperPlugin {
	init()
	block_call()
}

pub struct ViperRuntime {
pub mut:
	plugins []ViperPlugin
mut:
	tags map[string]Tag
}

pub fn new() ViperRuntime {
	return ViperRuntime {}
}

pub fn (mut r ViperRuntime) add_tag(tag Tag) {
	r.tags[tag.name] = tag
}

pub fn (mut r ViperRuntime) render(file string, variables map[string]string) string {
	input := os.read_file(file) or {
		error := FileError{
			filename: file,
			message: "File not found"
		}
		println(error.msg())
		exit(1)
	}

	mut parser := new_parser(
		file, 
		input,
		r
	)

	content, errors := parser.parse(variables)

	if errors.len > 0 {
		for error in errors {
			print(error.msg())
		}
		exit(1)
	}

	return content
}
