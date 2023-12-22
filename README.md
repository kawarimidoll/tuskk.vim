# tuskk.vim

**tuskk** (tˈʌsk) は [ripgrep](https://github.com/BurntSushi/ripgrep) を利用して
SKK ライクな日本語入力を行うプラグインです。

Vim および Neovim で動作します。

> [!WARNING]

> 現在鋭意開発中です。仕様は予告なく変更される場合があります。

## REQUIREMENTS

`keytrans()` および `:defer` が使用できるバージョンである必要があります。
なお、Vimでは[クラッシュバグ](https://github.com/vim/vim/issues/13609)の回避のため、
patch-9.0.2146 が必要です。

また、[ripgrep](https://github.com/BurntSushi/ripgrep) が必要です。

## EXAMPLE

設定の例を示します。

```vim
inoremap <c-j> <cmd>call tuskk#toggle()<cr>
cnoremap <c-j> <cmd>call tuskk#cmd_buf()<cr>

call tuskk#initialize({
    \ 'jisyo_list':  [
    \   { 'path': '~/.cache/vim/SKK-JISYO.L', 'encoding': 'euc-jp' },
    \   { 'path': '~/.cache/vim/SKK-JISYO.emoji', 'mark': '[E]' },
    \ ],
    \ 'kana_table': tuskk#opts#builtin_kana_table(),
    \ 'suggest_wait_ms': 200,
    \ 'suggest_sort_by': 'length',
    \ 'merge_tsu': v:true,
    \ 'trailing_n': v:true,
    \ })
```

## KNOWN ISSUE

Vimにおいて、tuskkが有効の状態で一定以上のスピードで入力すると、変換待ち・変換候補の文字列の描画がおかしくなる現象が確認されています。
