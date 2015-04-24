#!/usr/bin/env bats

@test "basic: Command help is shown without errors" {
    run repoman -h
    echo "$output"
    [[ $status -eq 0 ]]
    [[ ${output} =~ ^.*usage:\ repoman ]]
}

@test "basic: Wrong parameters returns error" {
    run repoman --dontexist
    echo "$output"
    [[ $status -eq 2 ]]
}
