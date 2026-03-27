local common = require("godotdev.docs.common")

local M = {}

local heading_levels = {
  ["="] = "#",
  ["-"] = "##",
  ["~"] = "###",
  ["^"] = "####",
  ['"'] = "#####",
}

local function normalize_whitespace(text)
  text = text:gsub("\r\n", "\n")
  text = text:gsub("[ \t]+\n", "\n")
  text = text:gsub("\n[ \t]+", "\n")
  text = text:gsub("\n\n\n+", "\n\n")
  return common.trim(text)
end

local function normalize_inline_rst(text)
  if text == "" then
    return ""
  end

  if
    not text:find("\\ ", 1, true)
    and not text:find("|", 1, true)
    and not text:find("`", 1, true)
    and not text:find(":", 1, true)
  then
    return common.trim(text)
  end

  text = text:gsub("\\ ", "")
  text = text:gsub("|bitfield|", "BitField")
  text = text:gsub("|const|", "const")
  text = text:gsub("|virtual|", "virtual")
  text = text:gsub("|vararg|", "vararg")
  text = text:gsub("|static|", "static")
  text = text:gsub("|operator|", "operator")
  text = text:gsub("``([^`]+)``", "`%1`")
  text = text:gsub(":ref:`([^`<]+)%s*<[^`>]+>`", "`%1`")
  text = text:gsub(":ref:`([^`]+)`", "`%1`")
  text = text:gsub(":doc:`([^`<]+)%s*<[^`>]+>`", "%1")
  text = text:gsub(":doc:`([^`]+)`", "%1")
  text = text:gsub(":abbr:`([^`<]+)%s*%(([^`]+)%)`", "%1 (%2)")
  text = text:gsub(":abbr:`([^`]+)`", "%1")
  text = text:gsub(":code:`([^`]+)`", "`%1`")
  text = text:gsub(":kbd:`([^`]+)`", "`%1`")
  text = text:gsub(":math:`([^`]+)`", "`%1`")
  text = text:gsub(":literal:`([^`]+)`", "`%1`")
  text = text:gsub("`([^`]+)`__", "%1")
  text = text:gsub("__%s*%.%.?$", "")
  return common.trim(text)
end

local function is_admonition(line)
  return line:match("^%.%. note::")
    or line:match("^%.%. warning::")
    or line:match("^%.%. tip::")
    or line:match("^%.%. important::")
    or line:match("^%.%. deprecated::")
end

local function consume_paragraph(lines, index)
  local paragraph = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    local next_line = lines[i + 1]

    if line == "" or line:match("^%s+$") then
      break
    end

    if line:match("^%.%. ") or line:match("^%+") or line:match("^%- ") then
      break
    end

    if next_line and next_line:match('^([=~%^"%-])%1+$') and #common.trim(line) > 0 then
      break
    end

    table.insert(paragraph, normalize_inline_rst(common.trim(line)))
    i = i + 1
  end

  return table.concat(paragraph, " "), i
end

local function split_table_row(line)
  local row = {}
  local inner = line:sub(2, -2)

  for cell in (inner .. "|"):gmatch("(.-)|") do
    table.insert(row, normalize_inline_rst(common.trim(cell)))
  end

  return row
end

local function format_markdown_table(rows)
  if #rows == 0 then
    return {}
  end

  local columns = 0
  for _, row in ipairs(rows) do
    columns = math.max(columns, #row)
  end

  for _, row in ipairs(rows) do
    while #row < columns do
      table.insert(row, "")
    end
  end

  local header = rows[1]
  local separator = {}
  local markdown = {
    "| " .. table.concat(header, " | ") .. " |",
  }

  for _ = 1, columns do
    table.insert(separator, "---")
  end
  table.insert(markdown, "| " .. table.concat(separator, " | ") .. " |")

  for i = 2, #rows do
    table.insert(markdown, "| " .. table.concat(rows[i], " | ") .. " |")
  end

  return markdown
end

local function consume_grid_table(lines, index)
  local rows = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    if not line:match("^%+") and not line:match("^|") then
      break
    end

    if line:match("^|") then
      table.insert(rows, split_table_row(line))
    end

    i = i + 1
  end

  return format_markdown_table(rows), i
end

local function consume_indented_block(lines, index, indent)
  local block = {}
  local i = index

  while i <= #lines do
    local line = lines[i]
    if line == "" then
      table.insert(block, "")
      i = i + 1
    elseif line:match("^" .. indent .. "%S") then
      local block_line = line:gsub("^" .. indent, "", 1)
      table.insert(block, block_line)
      i = i + 1
    else
      break
    end
  end

  return block, i
end

local function append_lines(output, lines_to_add)
  for _, line in ipairs(lines_to_add) do
    table.insert(output, line)
  end
end

function M.to_markdown(rst)
  local lines = vim.split(rst:gsub("\r\n", "\n"), "\n", { plain = true })
  local output = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local next_line = lines[i + 1]
    local trimmed = common.trim(line)

    if next_line and next_line:match('^([=~%^"%-])%1+$') and #trimmed > 0 then
      local marker = next_line:sub(1, 1)
      local heading = heading_levels[marker] or "##"
      table.insert(output, ("%s %s"):format(heading, normalize_inline_rst(trimmed)))
      table.insert(output, "")
      i = i + 2
    elseif line:match("^%.%. _") then
      i = i + 1
    elseif line:match("^%.%. rst%-class::") then
      i = i + 1
    elseif line:match("^%.%. code%-block::") then
      local language = common.trim(line:match("^%.%. code%-block::%s*(.*)$") or "")
      local block, next_index = consume_indented_block(lines, i + 1, "   ")
      table.insert(output, "```" .. language)
      append_lines(output, block)
      table.insert(output, "```")
      table.insert(output, "")
      i = next_index
    elseif is_admonition(line) then
      local kind = line:match("^%.%.%s+([%a_]+)::"):upper()
      local block, next_index = consume_indented_block(lines, i + 1, "   ")
      local markdown_block = { ("> [!%s]"):format(kind) }
      for _, block_line in ipairs(block) do
        if block_line == "" then
          table.insert(markdown_block, ">")
        else
          table.insert(markdown_block, "> " .. normalize_inline_rst(block_line))
        end
      end
      append_lines(output, markdown_block)
      table.insert(output, "")
      i = next_index
    elseif line:match("^%.%. ") then
      i = i + 1
    elseif line:match("^%+") then
      local markdown_table, next_index = consume_grid_table(lines, i)
      append_lines(output, markdown_table)
      table.insert(output, "")
      i = next_index
    elseif line:match("^%- ") then
      table.insert(output, "- " .. normalize_inline_rst(common.trim(line:sub(3))))
      i = i + 1
    elseif line:match("^%s+$") or line == "" then
      table.insert(output, "")
      i = i + 1
    else
      local paragraph, next_index = consume_paragraph(lines, i)
      if paragraph ~= "" then
        table.insert(output, paragraph)
        table.insert(output, "")
      end
      i = next_index
    end
  end

  return normalize_whitespace(table.concat(output, "\n"))
end

return M
