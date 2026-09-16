# Shared language selection for the installer and the server-only helper.
# Canonical groups correspond to one server each; C/C++ and JS/TS share servers.
normalize_lsp_languages() {
    local input="$1" item selected=',' result='' group
    [[ -n "$input" ]] || return 0
    case "$input" in ,*|*,|*,,*) echo 'LSP 语言列表不能包含空项' >&2; return 1 ;; esac
    local items=()
    IFS=',' read -r -a items <<< "$input"
    for item in "${items[@]}"; do
        case "$item" in
            c|cpp|c++) group=c ;;
            python|py) group=python ;;
            lua) group=lua ;;
            rust|rs) group=rust ;;
            javascript|js|typescript|ts) group=typescript ;;
            all) selected=',c,python,lua,rust,typescript,'; continue ;;
            none)
                [[ "$input" == none ]] && return 0
                echo 'none 不能与其他 LSP 语言混用' >&2; return 1 ;;
            *) echo "不支持的 LSP 语言：$item（支持 c/cpp、python、lua、rust、typescript/javascript、all、none）" >&2; return 1 ;;
        esac
        case "$selected" in *",$group,"*) ;; *) selected="$selected$group," ;; esac
    done
    for group in c python lua rust typescript; do
        case "$selected" in *",$group,"*) result="${result:+$result,}$group" ;; esac
    done
    printf '%s' "$result"
}
lsp_has() { case ",$LSP_LANGUAGES," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
lsp_needs_node() { lsp_has python || lsp_has typescript; }
