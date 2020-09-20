#!/bin/bash

xml2 < $1 | 2csv trkpt time @lat @lon ele
