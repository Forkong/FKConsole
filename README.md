## FKConsole
---- 
### What is this?
---- 
FKConsole是一个用于在Xcode控制台显示中文的插件。

![image](https://raw.githubusercontent.com/Forkong/FKConsole/master/Screenshots/demo.gif)


很多情况下，在程序中打印中文的时候：

	NSLog(@"%@", (@[@"测试", @"好的"]).description);

在控制台的输出往往是:

	(
	    "\U6d4b\U8bd5",
	    "\U597d\U7684"
	)

这不是我们想要的结果。

FKConsole就是为此而生的。FKConsole并不会影响你的程序，FKConsole只会对Xcode控制台内的文字进行处理，所以请放心使用。

开启FKConsole之后，控制台的输出会变成这样:

	(
	    "测试啊",
	    "好的"
	)

### How to install it?
---- 
你可以clone整个工程，然后编译，插件会自动安装到`~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`这个目录上。

一定要选Load Bundle，Skip的话，插件是无法生效的。

### How to use it?
---- 
点击Xcode的Plugins菜单，在FKConsole选项上可以进行勾选和取消勾选。

![image](https://raw.githubusercontent.com/Forkong/FKConsole/master/Screenshots/use.jpg)

### Xcode version?
---- 
- Xcode7
- Xcode6(未经测试)

### License
---- 
MIT.