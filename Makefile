
target=SearchInProjectWithAck.tmCommand

all: ${target}
	
${target}: search_with_ack.rb
	./gen_tmCommand.pl > ${target}

test: all
	open ${target}
