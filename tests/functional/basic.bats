#!/usr/bin/env bats

@test "basic: Command help is shown without errors" {
    run repoman -h
    [[ $status -eq 0 ]]
    [[ ${lines[0]} =~ ^usage:\ repoman ]]
}

@test "basic: Wrong parameters returns error" {
    run repoman --dontexist
    [[ $status -eq 2 ]]
}
