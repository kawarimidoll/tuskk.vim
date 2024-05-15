let pwd = expand('<script>:p:h')
execute $'set runtimepath+={pwd}'
execute $'helptags {pwd}/doc'

inoremap <c-j> <cmd>call tuskk#toggle()<cr>
cnoremap <c-j> <cmd>call tuskk#cmd_buf()<cr>

inoremap <c-k> <cmd>imap<cr>

let base_table = tuskk#opts#builtin_kana_table()
let azik_table = tuskk#opts#extend_azik_table()

let az_keys = azik_table->keys()
for k in az_keys
  if k[0] == k[1]
    unlet! azik_table[k]
  endif
endfor
unlet! azik_table[';']
unlet! azik_table['q']
let kana_table = extendnew(base_table, azik_table)

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call tuskk#initialize({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': '~/.cache/vim/SKK-JISYO.L', 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.geo', 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.station', 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.jawiki', 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': '~/.cache/vim/SKK-JISYO.emoji', 'encoding': 'utf-8' },
      \ ],
      \ 'kana_table': kana_table,
      \ 'suggest_wait_ms': 200,
      \ 'suggest_prefix_match_minimum': 5,
      \ 'suggest_sort_by': 'length',
      \ 'use_google_cgi': v:true,
      \ 'merge_tsu': v:true,
      \ 'trailing_n': v:true,
      \ 'abbrev_ignore_case': v:true,
      \ 'put_hanpa': v:true,
      \ 'debug_log_path': './local.log',
      \ })

" edit ./autoload/tuskk.vim
edit ./doc/tuskk.jax
