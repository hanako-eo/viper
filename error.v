module main

struct FileError {
	Error

	filename string
	message string
}

fn (err FileError) msg() string {
	return "\033[36m${err.filename}\033[0m \033[31mFileError\033[0m: ${err.message}"
}

struct TagError {
	Error

	filename string
	message string
	lines []string
	line int
	col int
	size int
}

fn (err TagError) get_lines() string {
	mut lines := ""

	if err.line-2 > 0 {
		lines += "${err.line-2:5} | ${err.lines[err.line-3]}\n"
	}
	if err.line-1 > 0 {
		lines += "${err.line-1:5} | ${err.lines[err.line-2]}\n"
	}
	lines += "${err.line:5} | ${err.lines[err.line-1]}\n${' '.repeat(5)} | ${' '.repeat(err.col-1)}\033[31m${'^'.repeat(err.size)}\033[0m\n"
	if err.line < err.lines.len {
		lines += "${err.line+1:5} | ${err.lines[err.line]}\n"
	}
	if err.line+1 < err.lines.len {
		lines += "${err.line+2:5} | ${err.lines[err.line+1]}\n"
	}

	return lines
}

fn (err TagError) msg() string {
	return "\033[36m${err.filename}\033[0m (\033[33m${err.line}\033[0m:\033[33m${err.col}\033[0m) \033[31mTagError\033[0m: ${err.message}\n${err.get_lines()}"
}

struct VarError {
	TagError
}

fn (err VarError) msg() string {
	return "\033[36m${err.filename}\033[0m (\033[33m${err.line}\033[0m:\033[33m${err.col}\033[0m) \033[31mVarError\033[0m: ${err.message}\n${err.get_lines()}"
}

struct SyntaxError {
	TagError
}

fn (err SyntaxError) msg() string {
	return "\033[36m${err.filename}\033[0m (\033[33m${err.line}\033[0m:\033[33m${err.col}\033[0m) \033[31mSyntaxError\033[0m: ${err.message}\n${err.get_lines()}"
}
