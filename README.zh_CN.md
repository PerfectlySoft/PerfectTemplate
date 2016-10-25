# PerfectTemplate [English](https://github.com/PerfectlySoft/PerfectTemplate)

<p align="center">
    <a href="http://perfect.org/get-involved.html" target="_blank">
        <img src="http://perfect.org/assets/github/perfect_github_2_0_0.jpg" alt="Get Involed with Perfect!" width="854" />
    </a>
</p>

<p align="center">
    <a href="https://github.com/PerfectlySoft/Perfect" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_1_Star.jpg" alt="Star Perfect On Github" />
    </a>  
    <a href="http://stackoverflow.com/questions/tagged/perfect" target="_blank">
        <img src="http://www.perfect.org/github/perfect_gh_button_2_SO.jpg" alt="Stack Overflow" />
    </a>  
    <a href="https://twitter.com/perfectlysoft" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_3_twit.jpg" alt="Follow Perfect on Twitter" />
    </a>  
    <a href="http://perfect.ly" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_4_slack.jpg" alt="Join the Perfect Slack" />
    </a>
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat" alt="Swift 3.0">
    </a>
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" alt="Platforms OS X | Linux">
    </a>
    <a href="http://perfect.org/licensing.html" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License Apache">
    </a>
    <a href="http://twitter.com/PerfectlySoft" target="_blank">
        <img src="https://img.shields.io/badge/Twitter-@PerfectlySoft-blue.svg?style=flat" alt="PerfectlySoft Twitter">
    </a>
    <a href="http://perfect.ly" target="_blank">
        <img src="http://perfect.ly/badge.svg" alt="Slack Status">
    </a>
</p>

Perfect Web服务器项目模板

本代码用于软件工程师在此基础之上开发Web服务器及其应用。您可以直接克隆本项目进行后续开发。该项目通过SPM软件包管理器编译，并能够生成一个可以独立运行的HTTP服务器。

###Swift兼容性

本项目必须使用Swift 3.0工具链及Xcode 8.0+，或者通过Linux安装[Swift.org](http://swift.org/)。

## Swift 版本注意事项

因为Xcode 8发行后出现了一些问题，如果您直接在Xcode下使用，我们建议安装swiftenv，以及 Swift 3.0.1 工具集预览版。

```
# after installing swiftenv from https://swiftenv.fuller.li/en/latest/
swiftenv install https://swift.org/builds/swift-3.0.1-preview-1/xcode/swift-3.0.1-PREVIEW-1/swift-3.0.1-PREVIEW-1-osx.pkg
```

还有一种方式，就是在您Xcode中增加一个配置，即在项目设置“Project Settings”里面，查找条目“Library Search Paths”，然后将这个条目配置为“$(PROJECT_DIR)”，并且⚠️配置为⚠️递归形式“recursive”。这样就会通知编译器根据项目所在文件夹进行递归式检索项目所需要的函数库和参考引用。

## 编译运行

为了创建项目并且试验运行，请在终端命令行中输入以下内容。完成后就可以实现一个在本地网络8181端口工作的Web服务器。

```
git clone https://github.com/PerfectlySoft/PerfectTemplate.git
cd PerfectTemplate
swift build
.build/debug/PerfectTemplate
```

如果没有问题，输出应该看起来像是这样：

```
Starting HTTP server on 0.0.0.0:8181 with document root ./webroot
```

这表明服务器已经准备好并且等待连接了。请访问[http://localhost:8181/](http://127.0.0.1:8181/) 来查看欢迎信息。在终端命令行上输入control-c组合键即可停止Web服务。

## 快速上手

以下的源代码展示了一个最简单的“你好，世界！”样例。

```swift
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer

// 创建HTTP服务器
let server = HTTPServer()

// 注册自定义路由和页面句柄
var routes = Routes()
routes.add(method: .get, uri: "/", handler: {
		request, response in
		response.appendBody(string: "<html><head><meta http-equiv='content-type' content='text/html;charset=utf-8'><title>你好，世界！</title></head><body>你好，世界！</body></html>")
		response.completed()
	}
)

// 将路由注册到服务器
server.addRoutes(routes)

// 监听8181端口
server.serverPort = 8181

// 设置文档根目录。
// 这个操作是可选的，如果没有静态页面内容则可以忽略这一步。
// 设置文档根目录后，对于其他所有未经过滤器或已注册路由来说的其他路径“/**”，都会指向这个根目录下的文件。
server.documentRoot = "./webroot"

// 逐个检查命令行参数和服务器配置
// 如果用命令行执行带 --help 参数的服务器可执行程序，就可以看到所有可以选择的参数。
// 如果调用时在命令行参数，而且该参数在配置文件中也有说明，则命令行参数的值会取代配置文件。
configureServer(server)

do {
	// 启动HTTP服务器
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("网络异常： \(err) \(msg)")
}
```



## 问题报告

目前我们已经把所有错误报告合并转移到了JIRA上，因此github原有的错误汇报功能不能用于本项目。

您的任何宝贵建意见或建议，或者发现我们的程序有问题，欢迎您在这里告诉我们。[http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1)。

目前问题清单请参考以下链接： [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)



## 更多内容
关于Perfect更多内容，请参考[perfect.org](http://perfect.org)官网。
