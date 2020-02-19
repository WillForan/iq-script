AppName:=`dirname $(PWD)`
.PHONY: run

bin/${AppName}.prg: manifest.xml $(wildcard source/*.mc) $(wildcard resources/**) ${DEVELOPER_KEY}  
	monkeyc -o bin/${AppName}.prg -d ${DEVICE} -m manifest.xml -z `find . -path './resources*.xml' | xargs | tr ' ' ':'`\
	   source/*.mc -w -y ${DEVELOPER_KEY}

run: bin/${AppName}.prg
	@killall simulator
	connectiq
	monkeydo $< ${DEVICE}
