# Copyright (C) 2016 PerfectlySoft Inc.
# Author: Shao Miller <swiftcode@synthetel.com>

FROM perfectlysoft/ubuntu1510
RUN /usr/src/Perfect-Ubuntu/install_swift.sh --sure
RUN git clone https://github.com/PerfectlySoft/PerfectTemplate /usr/src/PerfectTemplate
WORKDIR /usr/src/PerfectTemplate
RUN swift build
CMD .build/debug/PerfectTemplate --port 80
