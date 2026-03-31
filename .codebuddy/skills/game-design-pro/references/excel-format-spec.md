# 策划案Excel格式规范与JSON定义

本文档定义了策划案Excel的样式体系、排版规则，以及用于驱动`generate_design_doc.py`脚本的JSON定义Schema。

**核心原则**：Excel生成基于`assets/template.xlsx`模板文件复制+样式克隆，所有样式精确还原【规范】系统策划案模板的视觉风格。

---

## 一、Excel整体结构

### 1.1 Sheet顺序

标准策划案的Sheet按以下顺序排列：

1. 版本号
2. 交互（交互说明）
3. 功能说明
4. 红点逻辑
5. 配置需求
6. IP&Icon需求
7. 埋点&GM需求
8. [补充案Sheet...] （如规则QA、版本改动等）

### 1.2 通用布局规则

- **A列留空**：所有内容从B列开始，A列宽度9.0作为左边距
- **R1留空**：第一行留空，内容从R2开始
- **模块间距**：不同内容区块之间空1~2行
- **Sheet页签颜色**：无特殊要求，默认即可

---

## 二、样式体系（精确还原模板）

### 2.1 字体规范

所有字体统一使用**等线**，颜色使用**theme颜色**而非RGB硬编码。

| 元素 | 字体 | 大小 | 粗细 | 颜色 |
|------|------|------|------|------|
| Sheet大标题 | 等线 | 22pt | 加粗 | theme=0 白色 |
| 二级标题 | 等线 | 14pt | 加粗 | theme=0 白色 |
| 版本号标签 | 等线 | 12pt | 加粗 | theme=0 白色 |
| 版本号值 | 等线 | 11pt | 常规 | theme=1 黑色 |
| 正文 | 等线 | 11pt | 常规 | theme=1 黑色 |
| 注释行(//前缀) | 等线 | 11pt | 常规 | theme=4 蓝色 |
| 数据表头 | 等线 | 11pt | 加粗 | theme=0 白色 |
| 三级标题 | 等线 | 11pt | 加粗 | theme=1 黑色 |
| 层级标记(▸) | Segoe UI Symbol | 11pt | 常规 | theme=1 黑色 |

### 2.2 填充颜色规范

所有背景色使用**theme颜色+tint**组合：

| 用途 | theme | tint | 视觉效果 |
|------|-------|------|----------|
| Sheet大标题背景 | 4 | -0.5 | 深蓝色 |
| 二级标题背景 | 4 | -0.25 | 蓝色 |
| 版本号值背景 | 3 | 0.9 | 极浅棕 |
| 数据表头背景 | 3 | 0.5 | 橄榄绿 |
| 浅数据表头背景 | 3 | 0.6 | 浅橄榄绿 |
| 配置表头背景 | 0 | -0.15 | 浅灰 |
| 红点表头背景 | 0 | -0.05 | 极浅灰 |

### 2.3 对齐规范

| 元素 | 水平对齐 | 垂直对齐 | 自动换行 |
|------|----------|----------|----------|
| 大标题/二级标题 | 左对齐 | 居中 | 否 |
| 正文 | 左对齐 | 居中 | 否 |
| 概述文本 | 左对齐 | 顶部 | 是 |
| 表格数据 | 左对齐/居中 | 居中 | 是 |

### 2.4 行高与列宽

| 元素 | 行高 |
|------|------|
| Sheet大标题 | 34.5 |
| 二级标题 | 18.0 |
| 版本号标签 | 15.75 |
| 正文 | 14.25 |
| 表头 | 15.75 |
| 表格数据行 | 20.1 |
| 图片占位 | 150 |

### 2.5 边框规范

- 所有表格区域使用 **thin** 样式边框（四边）
- 非表格区域（正文、注释行）无边框
- 标题行无边框

---

## 三、合并单元格规则

### 3.1 标题合并

- **Sheet大标题**：合并 B:U 列
- **二级标题**：合并 B:L 列
- **版本号标签/值**：合并 B:D 列
- **概述标签**：合并 B:K 列
- **概述内容**：合并 B12:K45

### 3.2 各Sheet特殊合并

**交互Sheet**：
- "详细"列：合并 C:E
- "说明"列：合并 G:W

**配置需求Sheet**：
- "字段名"列：合并 B:C
- "字段说明"列：合并 G:M

**红点逻辑Sheet**：
- 每列用2列合并

**埋点&GM需求Sheet**：
- 每列用2列合并（B:C, D:E, F:G, H:I, J:K, L:Q）

---

## 四、层级缩进规则

| 层级 | 标记列 | 标记 | 内容列 |
|------|--------|------|--------|
| 三级标题 | B | （无） | B |
| 一级规则 | B | `▸` | C |
| 二级规则 | C | `--` | D |
| 三级规则 | D | `--` | E |

---

## 五、JSON定义Schema

`generate_design_doc.py`脚本接收以下JSON结构来生成Excel文件。

### 5.1 顶层结构

```json
{
  "file_name": "【系统】内城农民氛围气泡",
  "sheets": [
    { "name": "版本号", "type": "version_info", "data": { ... } },
    { "name": "交互", "type": "interaction", "data": { ... } },
    { "name": "功能说明", "type": "feature_spec", "data": { ... } },
    { "name": "红点逻辑", "type": "red_dot", "data": { ... } },
    { "name": "配置需求", "type": "config_spec", "data": { ... } },
    { "name": "IP&Icon需求", "type": "ip_icon", "data": { ... } },
    { "name": "埋点&GM需求", "type": "tracking_gm", "data": { ... } }
  ]
}
```

### 5.2 版本号Sheet（type: "version_info"）

```json
{
  "version": "1.0",
  "author": "Apakoh(喻骋远)",
  "title": "内城农民氛围气泡",
  "summary": "通过增加内城农民的动态气泡反馈，以增强内城模拟经营感与时代沉浸感"
}
```

### 5.3 交互Sheet（type: "interaction"）

```json
{
  "art_assets": [
    {
      "category": "UI界面",
      "detail": "召唤主界面（不含卡池封面）",
      "count": 1,
      "note": "界面prefab"
    }
  ],
  "art_asset_comments": ["//自定义注释（可选）"],
  "flow_overview": {
    "description": "主要界面流转说明文本",
    "links": ["https://xxx.feishu.cn/wiki/xxx"]
  },
  "detail_views": [
    {
      "view_name": "材料副本主界面",
      "description": "界面详细UE说明...",
      "links": []
    }
  ]
}
```

### 5.4 功能说明Sheet（type: "feature_spec"）

```json
{
  "sections": [
    {
      "title": "副本关卡解锁规则",
      "subsections": [
        {
          "title": "1.1.功能入口",
          "rules": [
            {
              "level": 1,
              "marker": "▸",
              "text": "副本关卡随主线关卡进度逐步解锁",
              "children": [
                {
                  "level": 2,
                  "marker": "--",
                  "text": "当主线进度达到X章节时解锁"
                }
              ]
            }
          ],
          "paragraphs": ["补充文本段落"],
          "tables": [
            {
              "headers": ["阶段", "优先级", "触发器"],
              "rows": [["收集阶段", "High", "定时器"]]
            }
          ],
          "notes": ["补充说明"],
          "images": ["界面截图描述"]
        }
      ]
    }
  ]
}
```

### 5.5 红点逻辑Sheet（type: "red_dot"）

```json
{
  "flow_description": "可选的流转图描述",
  "entries": [
    {
      "description": "红点情况描述",
      "ui_path": "MainCity > TestSystem > Entry",
      "trigger": "有未领取的奖励时显示",
      "dismiss": "领取后消失",
      "dot_type": "★"
    }
  ]
}
```

### 5.6 配置需求Sheet（type: "config_spec"）

```json
{
  "tables": [
    {
      "table_name": "新增TestConfig表（测试配置）",
      "is_new": true,
      "fields": [
        {
          "field_name": "配置ID",
          "en_name": "ConfigID",
          "data_type": "int",
          "table_type": "3",
          "description": "唯一标识ID"
        }
      ]
    }
  ]
}
```

**注意**：`table_type` 字段为打表类型（2=客户端表, 3=服务端表），在Excel中会生成对应的列。

### 5.7 IP&Icon需求Sheet（type: "ip_icon"）

```json
{
  "item_requirements": [
    {
      "item_id": "10001",
      "item_name": "",
      "item_type": "消耗品",
      "icon_desc": "参考原画XX",
      "icon_ref": "",
      "item_desc": ""
    }
  ],
  "ip_requirements": [
    {
      "content": "遗产玩法",
      "pack_type": "系统功能名",
      "count": "1",
      "text_pack": "（临时）适格",
      "char_limit": "≤4"
    }
  ],
  "naming_requirements": [],
  "dialogues": [
    {
      "text": "这里的浆果很酸。",
      "condition": "≤黑暗时代；任意状态"
    }
  ],
  "function_texts": [
    {
      "title": "限时活动",
      "content": "活动内容详细文案..."
    }
  ]
}
```

### 5.8 埋点&GM需求Sheet（type: "tracking_gm"）

```json
{
  "snapshots": [
    {
      "timing": "Logout",
      "field_name": "legacy",
      "description": "遗产",
      "format": "90001-2;90002-1",
      "category": "功能类",
      "note": "遗产id-等级"
    }
  ],
  "tracking_events": [
    {
      "category": "氛围气泡",
      "sub_category": "曝光统计",
      "ownership": "client",
      "event": "bubble_generate",
      "name": "生成气泡",
      "fields": "bubble_type;bubble_id"
    }
  ],
  "gm_commands": [
    {
      "command": "gm_show_bubble",
      "params": "targetid;bubbleid",
      "description": "强制在指定ID的对象身上生成指定ID的气泡"
    }
  ]
}
```

### 5.9 通用内容块Sheet（type: "generic"）

```json
{
  "blocks": [
    { "type": "sheet_title", "text": "规则QA" },
    { "type": "section_title", "text": "子模块标题" },
    { "type": "subtitle", "text": "三级标题" },
    { "type": "paragraph", "text": "正文段落...", "merge_cols": 10 },
    { "type": "comment", "text": "//注释说明" },
    { "type": "rule", "level": 1, "marker": "▸", "text": "规则内容", "children": [] },
    { "type": "rules", "items": [ ... ] },
    { "type": "table", "headers": ["A", "B"], "rows": [["1", "2"]] },
    { "type": "image_placeholder", "description": "界面流转图" },
    { "type": "empty", "count": 2 }
  ]
}
```

---

## 六、脚本调用方式

### 6.1 命令行调用

```bash
python generate_design_doc.py <json_file_path> [output_dir]
```

- `json_file_path`：JSON定义文件路径
- `output_dir`：可选，输出目录，默认为当前目录

### 6.2 模板依赖

脚本依赖 `assets/template.xlsx` 作为基底模板。如模板不存在，会回退创建新工作簿（但将缺少theme颜色支持）。

### 6.3 输出文件

- 文件名格式：`{file_name}.xlsx`
- 文件名来自JSON定义中的`file_name`字段
- 自动添加`.xlsx`扩展名
