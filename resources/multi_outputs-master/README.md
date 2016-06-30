# Introduction

これは、複数の実行結果の表示と保存を可能とする、Jupyter Notebook Extensionです。

# Setup

## 1. manual instration

1. make the `nbextensions` folder to `~/.ipython/`
2. copy the `multi_outputs` folder to `~/.ipython/nbextensions/`

## 2. configuration

make (or edit) youre `~/.jupyter/nbconfig/notebook.json` file

```
{
  "load_extensions": {
    "multi_outputs/main": true
  }
}
```

## 3. 使用する

1. 既存のnotebook、または新しいnotebookを作成し開きます
2. メニューの[View] - [Cell Toolbar] - [Multi outputs]を選びます
3. セルのツールバーにmulti outputsチェックボックスが表示されるので、複数の出力を保持したいセルのチェックボックスをonにします
  - なお、multi outputsチェックボックスのon/offを行うと、実行結果はクリアされます
4. チェックボックスをonにしたセルを実行すると、実行結果をタブ形式で表示します。
5. 通常と同じ手順でnotebookを保存してください。notebookを開いた時、この拡張が有効であれば、再びタブ形式で表示します。

# License

This project is licensed under the terms of the Modified BSD License (also known as New or Revised or 3-Clause BSD), see LICENSE.txt.
