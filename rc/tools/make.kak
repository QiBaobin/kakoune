declare-option -docstring "shell command run to build the project" \
    str makecmd make
declare-option -docstring "pattern that describes lines containing information about errors in the output of the `makecmd` command. Capture groups must be: 1: filename 2: line number 3: optional column 4: optional error description" \
    regex make_error_pattern "^([^:\n]+):(\d+):(?:(\d+):)? (?:fatal )?error:([^\n]+)?"

provide-module make %{

require-module fifo
require-module jump

define-command -params .. -docstring %{
    make [<arguments>]: make utility wrapper
    All the optional arguments are forwarded to the make utility
} make %{
    evaluate-commands -try-client %opt{toolsclient} -save-regs a %{
        set-register a %opt{make_error_pattern} # save current error_pattern
        fifo -scroll -name *make* -script %{
            trap - INT QUIT
            $kak_opt_makecmd "$@"
        } %arg{@} # pass arguments for "$@" above, exit to avoid evaluating them
        set-option buffer filetype make
        set-option buffer jump_current_line 0
        set-option buffer make_error_pattern %reg{a} # set the pattern to the value while firing the make command
    }
}

add-highlighter shared/make group
add-highlighter shared/make/ regex "^\h*(~*(?:(\^)~*)?)$" 1:green 2:cyan+b
add-highlighter shared/make/ line '%opt{jump_current_line}' default+b

hook -group make-highlight global WinSetOption filetype=make %{
    add-highlighter -override shared/make/ regex %opt{make_error_pattern} 1:cyan 2:green 3:green 4:red 5:yellow 6:blue 7:yellow
    add-highlighter window/make ref make
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/make }
}

hook global WinSetOption filetype=make %{
    alias buffer jump make-jump
    alias buffer jump-select-next make-select-next
    alias buffer jump-select-previous make-select-previous
    hook buffer -group make-hooks NormalKey <ret> make-jump
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer make-hooks }
}

define-command -hidden make-open-error -params 4 %{
    evaluate-commands -try-client %opt{jumpclient} %{
        edit -existing "%arg{1}" %arg{2} %arg{3}
        echo -markup "{Information}{\}%arg{4}"
        try %{ focus }
    }
}

define-command -hidden make-jump %{
    evaluate-commands -save-regs a/ %{
        evaluate-commands -draft %{
            execute-keys ,
            try %{
                execute-keys gl<a-?> "Entering directory" <ret><a-:>
                # Try to parse the error into capture groups, failing on absolute paths
                execute-keys s "Entering directory [`']([^']+)'.*\n([^:\n/][^:\n]*):(\d+):(?:(\d+):)?([^\n]+)\n?\z" <ret>l
                set-option buffer jump_current_line %val{cursor_line}
                set-register a "%reg{1}/%reg{2}" "%reg{3}" "%reg{4}" "%reg{5}"
            } catch %{
                set-register / %opt{make_error_pattern}
                execute-keys <a-h><a-l> s<ret>l
                set-option buffer jump_current_line %val{cursor_line}
                set-register a "%reg{1}" "%reg{2}" "%reg{3}" "%reg{4}"
            }
        }
        make-open-error %reg{a}
    }
}
define-command -hidden make-select-next %{
        set-register / %opt{make_error_pattern}
        execute-keys "%opt{jump_current_line}ggl" "/<ret>"
}
define-command -hidden make-select-previous %{
        set-register / %opt{make_error_pattern}
        execute-keys "%opt{jump_current_line}g" "<a-/><ret>"
}

define-command make-next-error -docstring %{alias for "jump-next *make*"} %{
    jump-next *make*
}

define-command make-previous-error -docstring %{alias for "jump-previous *make*"} %{
    jump-previous *make*
}

}

hook -once global KakBegin .* %{ require-module make }
