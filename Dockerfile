# Copyright (C) 2016 PerfectlySoft Inc.
# Author: Shao Miller <swiftcode@synthetel.com>

FROM perfectlysoft/perfectassistant
RUN apt-get update -y && apt-get install clang openssl libssl-dev uuid-dev libcurl3 -y
ADD Package.swift /usr/src/SwiftProject/Package.swift
ADD Sources/* /usr/src/SwiftProject/Sources/
WORKDIR /usr/src/SwiftProject
RUN swift build
CMD .build/debug/PerfectTemplate --port 8080
