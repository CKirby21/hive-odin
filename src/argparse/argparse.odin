package argparse

import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:log"

ArgumentParser :: struct {
    description: string,
    options: [dynamic]Option
}

Action :: enum {
    Store,
    StoreTrue,
    StoreFalse,
}

Option :: struct {
    value: Value,
    names: []string,
    action: Action,
    help: string
}

Value :: union {
    ^string,
    ^int,
    ^bool,
}

new_argument_parser :: proc() -> ArgumentParser {
    return ArgumentParser{}
}

print_usage :: proc(ap: ArgumentParser, input_args := os.args) {
    fmt.println("Usage:")
    fmt.printfln("\t%s", input_args[0])
    fmt.println()
    for option in ap.options {
        fmt.print("\t")
        for name, i in option.names {
            fmt.print(name)
            if i != len(option.names) - 1 {
                fmt.print(", ")
            }
        }
        if option.action == .Store {
            switch _ in option.value {
            case ^string:
                fmt.printfln(" <string>")
            case ^int:
                fmt.printfln(" <int>")
            case ^bool:
                fmt.println()
            }
        }
        if option.help == "" {
            fmt.println()
        } else {
            fmt.printfln("\t\t%s", option.help)
            fmt.println()
        }
    }
}

add_description :: proc(ap: ^ArgumentParser, description: string) {
    ap.description = description
}

add_option :: proc(ap: ^ArgumentParser, value: Value, names: []string, action: Action, help: string) {
    append(&ap.options, Option{ value, names, action, help })
}

parse_args_or_exit :: proc(ap: ArgumentParser, input_args := os.args) {
    exit := parse_args(ap, input_args)
    if exit {
        os.exit(1)
    }
}

@(require_results)
parse_args :: proc(ap: ArgumentParser, input_args := os.args) -> (exit: bool) {

    for i in 1..<len(input_args) {
        switch input_args[i] {
        case "-help", "-h":
            print_usage(ap, input_args)
            return true
        }
    }

    i := 1 // Start at 1 to skip program name
    for i < len(input_args) {
        input_arg_found := false
        for &option in ap.options {
            for name in option.names {
                if name == input_args[i] {
                    input_arg_found = true
                }
            }
            if !input_arg_found {
                continue
            }
            switch option.action {
            case .Store:
                if i + 1 >= len(input_args) {
                    print_usage(ap, input_args)
                    return true
                }
                value_str := input_args[i+1]
                switch _ in option.value {
                case ^string:
                    option.value.(^string)^ = value_str
                case ^int:
                    value, ok := strconv.parse_int(value_str)
                    if !ok {
                        fmt.printfln("Unable to parse <%s> to int", value_str)
                        return true
                    }
                    option.value.(^int)^ = value
                case ^bool:
                }
                i += 2
            case .StoreTrue:
                option.value.(^bool)^ = true
                i += 1
            case .StoreFalse:
                option.value.(^bool)^ = false
                i += 1
            }
        }
        if !input_arg_found {
            print_usage(ap, input_args)
            return true
        }
    }
    return false
}

close :: proc(ap: ^ArgumentParser) {
    delete(ap.options)
}

