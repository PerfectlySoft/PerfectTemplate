# PerfectTemplate [English](https://github.com/PerfectlySoft/PerfectTemplate) [简体中文](README.zh_CN.md)

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
        <img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift 4.0">
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

Чистый начальный проект Perfect

Данный репозиторий содержит чистый проект Perfect, который можно клонировать и использовать при начале новой работы. Он собирается с помощью Swift Package Manager и запускает автономный HTTP.

## Совместимость со Swift

Ветка master этого проекта компилируется в **Xcode 9.1** и в **Swift 4.0.2** на Ubuntu.

## Сборка и Запуск

Клонирование и сборка чистого начального проекта, а также запуск сервера на порте 8080 и 8181.

```
git clone https://github.com/PerfectlySoft/PerfectTemplate.git
cd PerfectTemplate
swift run
```

После этого должно вывестись:

```
[INFO] Starting HTTP server localhost on 0.0.0.0:8181
```

Это значит, что сервер запущен и ожидает соединений. Перейдите на [http://localhost:8181/](http://127.0.0.1:8181/), чтобы увидеть приветствие. Нажмите control-c для остановки сервера.

## Начальное содержание

Файл примера содержит простой обработчик запросов "hello, world!" и показывает, как хранить статические файлы, сжимать исходящий контент и запускать сверх одного сервера за раз.

```swift
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer

// Пример обработчика запроса.
// Функция 'handler' будет указана непосредственно в конфигурации ниже.
func handler(data: [String:Any]) throws -> RequestHandler {
	return {
		request, response in
		// Ответ простым сообщением.
		response.setHeader(.contentType, value: "text/html")
		response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
		// Убедитесь, что вызывается response.completed() в конце функции обработчика.
		response.completed()
	}
}

// Конфигурация сервера-примера.
// Данный пример конфигурации показывает, как запускать сервер
// используя dictionary с ней.


let confData = [
	"servers": [
		// Конфигурация для одного сервера, который:
		//	* Хранит сообщение hello world на <host>:<port>/
		//	* Хранит статические файлы в директории "./webroot"
		//		(которая должна быть размещена в данной рабочей директории).
		//	* По необходимости сжимает исходящие данные.
		[
			"name":"localhost",
			"port":8181,
			"routes":[
				["method":"get", "uri":"/", "handler":handler],
				["method":"get", "uri":"/**", "handler":PerfectHTTPServer.HTTPHandler.staticFiles,
				 "documentRoot":"./webroot",
				 "allowResponseFilters":true]
			],
			"filters":[
				[
				"type":"response",
				"priority":"high",
				"name":PerfectHTTPServer.HTTPFilter.contentCompression,
				]
			]
		]
	]
]

do {
	// Запуск серверов на основе конфигурации.
	try HTTPServer.launch(configurationData: confData)
} catch {
	fatalError("\(error)") // fatal error при запуске одного из серверов
}
```


## Проблемы

Мы переходим к использованию JIRA для всех багов и решения проблем, поэтому GitHub Issues отключены.

Если вы нашли ошибку, баг, или у вас есть любое другое полезное предложение по документации, пожалуйста, перейдите на [http://jira.perfect.org:8080/servicedesk/customer/portal/1](http://jira.perfect.org:8080/servicedesk/customer/portal/1) и напишите об этом.

Весь список известных проблем находится на [http://jira.perfect.org:8080/projects/ISS/issues](http://jira.perfect.org:8080/projects/ISS/issues)



## Дальнейшая информация
Для большей информации о проекте Perfect, пожалуйста, посетите [perfect.org](http://perfect.org).
