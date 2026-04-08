# Check if terminal supports Cape sequences
if [ -t 1 ] && command -v tput &>/dev/null; then
  # Colors
  if [ "$(tput colors)" -ge 8 ]; then
    C_RED="$(tput setaf 1)"
    C_GREEN="$(tput setaf 2)"
    C_YELLOW="$(tput setaf 3)"
    C_BLUE="$(tput setaf 4)"
    C_MAGENTA="$(tput setaf 5)"
    C_CYAN="$(tput setaf 6)"
    C_WHITE="$(tput setaf 7)"
    C_BOLD="$(tput bold)"
    C_UNDERLINE="$(tput smul)"
    C_RESET="$(tput sgr0)"
  else
    C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
    C_MAGENTA="" C_CYAN="" C_WHITE="" C_BOLD="" C_UNDERLINE="" C_RESET=""
  fi

  # Cursor control
  C_HIDE_CURSOR="$(tput civis 2>/dev/null || echo "")"
  C_SHOW_CURSOR="$(tput cnorm 2>/dev/null || echo "")"
  C_CLEAR_SCREEN="$(tput clear 2>/dev/null || echo "")"
  C_MOVE_HOME="$(tput cup 0 0 2>/dev/null || echo "")"

  # Bell
  C_BELL="$(tput bel 2>/dev/null || echo "")"

else
  # Fallback: terminal not interactive or tput missing
  C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
  C_MAGENTA="" C_CYAN="" C_WHITE="" C_BOLD="" C_UNDERLINE="" C_RESET=""
  C_HIDE_CURSOR="" C_SHOW_CURSOR="" C_CLEAR_SCREEN="" C_MOVE_HOME=""
  C_BELL=""
fi

# term_test() {
#   local empty=""
#   for mod in C_RESET C_BOLD C_UNDERLINE; do
#     for color in empty C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE; do
#       eval "echo \"\${$mod}\${$color}\$mod \$color\$C_RESET\""
#     done
#   done

#   echo "Ringing bell in 3s..."
#   sleep 3
#   echo "${C_BELL}DING!!!"
#   echo "Done!"
# }
