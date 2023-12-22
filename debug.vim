let pwd = expand('<script>:p:h')
execute $'set runtimepath+={pwd}'
execute $'helptags {pwd}/doc'

inoremap <c-j> <cmd>call tuskk#toggle()<cr>
cnoremap <c-j> <cmd>call tuskk#cmd_buf()<cr>

inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call tuskk#init({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': '~/.cache/vim/SKK-JISYO.L', 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.geo', 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.station', 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.jawiki', 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.emoji', 'encoding': 'utf-8' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.nicoime', 'encoding': 'utf-8', 'mark': '[N]' },
      \ ],
      \ 'kana_table': tuskk#opts#builtin_kana_table(),
      \ 'suggest_wait_ms': 200,
      \ 'suggest_prefix_match_minimum': 5,
      \ 'suggest_sort_by': 'length',
      \ 'debug_log': '',
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ 'trailing_n': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'put_hanpa': v:true,
      \ })

" edit ./autoload/tuskk.vim
edit ./doc/tuskk.jax
