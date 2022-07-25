module main

pub struct Context {
pub mut:
	data map[string]string
}

pub fn new_context(data map[string]string) Context {
	return Context {
		data: data
	}
}

pub fn (c Context) get(key string) string {
	return c.data[key].str()
}