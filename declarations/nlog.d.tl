local nlog = record
	getLevel: function(): number
	info: function(tag: string, text: string)
	infof: function(tag: string, text: string, ...: any)
	warn: function(tag: string, text: string)
	warnf: function(tag: string, text: string, ...: any)
	warning: function(tag: string, text: string)
	warningf: function(tag: string, text: string, ...: any)
	error: function(tag: string, text: string)
	errorf: function(tag: string, text: string, ...: any)
	debug: function(tag: string, text: string)
	debugf: function(tag: string, text: string, ...: any)
end

return nlog
