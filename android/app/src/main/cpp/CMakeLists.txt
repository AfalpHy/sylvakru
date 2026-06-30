cmake_minimum_required(VERSION 3.22.1)

project(sylvakru_usb_exclusive)

add_library(
    sylvakru_usb_exclusive
    SHARED
    usb_exclusive_engine.cpp
)

find_library(log-lib log)

target_link_libraries(
    sylvakru_usb_exclusive
    ${log-lib}
)
