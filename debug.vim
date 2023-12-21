execute $"set runtimepath+={expand('<script>:p:h')}"

inoremap <c-j> <cmd>call tuskk#toggle()<cr>
" cnoremap <c-j> <cmd>call cmd_buf#run('tuskk#enable')<cr>

inoremap <c-k> <cmd>imap<cr>

let uj = expand('~/.cache/vim/SKK-JISYO.user')
call tuskk#init({
      \ 'user_jisyo_path': uj,
      \ 'jisyo_list':  [
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.L'), 'encoding': 'euc-jp', 'mark': '[L]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.geo'), 'encoding': 'euc-jp', 'mark': '[G]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.station'), 'encoding': 'euc-jp', 'mark': '[S]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.jawiki'), 'encoding': 'utf-8', 'mark': '[W]' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.emoji'), 'encoding': 'utf-8' },
      \   { 'path': expand('~/.cache/vim/SKK-JISYO.nicoime'), 'encoding': 'utf-8', 'mark': '[N]' },
      \ ],
      \ 'kana_table': tuskk#opts#default_kana_table(),
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

edit /Users/kawarimidoll/ghq/github.com/kawarimidoll/tuskk.vim/autoload/tuskk.vim
