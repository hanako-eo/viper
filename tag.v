module main

pub struct Tag {
pub mut:
	name string
	self_closing bool
	
	handle fn (string, string) string
}
