# Introduction

これは、セルのステータスを表示する、Jupyter Notebook Extensionです。

# Setup

## 1. manual instration

1. make the `nbextensions` folder to `~/.ipython/`
2. copy the `code_cell_status` folder to `~/.ipython/nbextensions/`

## 2. configuration

make (or edit) youre `~/.jupyter/nbconfig/notebook.json` file

```
{
  "load_extensions": {
    "code_cell_status/main": true
  }
}
```

## 3. 使用する

1. 通常と同じ手順でnotebookを使用してください。セルを実行すると実行状態が色によって可視化されます。

# License

This project is licensed under the terms of the Modified BSD License (also known as New or Revised or 3-Clause BSD), see LICENSE.txt.
