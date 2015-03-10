#
#
# JuniperHash builds a nested hash out of a juniper
# configuration file.
#
# Usage:
# require 'juniper_hash'
# hash_config = JuniperHash.get_hash(File.open('juniper.conf').read)
# text_config = JuniperHash.build_config_from_hash(hash_config)
# JuniperHash.get_hash(text_config) == hash_config
# => true
#
#
#  Copyright (C) 2015, Sven Tantau <sven@beastiebytes.com>
#
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  "Software"), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
#
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class JuniperHash
  # takes a string and returns a nested hash
  def self.get_hash(content_string)
    lines_array = content_string.split("\n")
    # remove the comments
    comment_free_lines_array = lines_array.select { |x| !(x =~ /^#/) }
    # do the work:
    format_blocks_to_hash(comment_free_lines_array)
  end

  # generate config from hash
  def self.build_config_from_hash(block, name = nil, level = 0)
    indent = '  ' * level
    out = ''
    if name
      out = indent + name + " {\n"
      level += 1
    end
    indent = '  ' * level
    block.each do |key, value|
      if value.empty?
        out += indent + key + ";\n"
      elsif value.is_a? String
        out += indent + key + ' ' + value + ";\n"
      elsif value.is_a? Array
        value.each do |v|
          out += indent + key + ' ' + v + ";\n"
        end
      elsif value.is_a? Hash
        out += build_config_from_hash(value, key, level)
      end
    end
    if name
      level -= 1
      indent = '  ' * level
      out += indent + "}\n"
    end
    out
  end

  def self.extract_key_value_from_line(line)
    key, value = line.split(' ', 2).collect(&:strip)
    if value
      # example line:
      # instance-type vrf;
      return [key, value.gsub(/;$/, '')]
    else
      # example line:
      # vlan-tagging;
      return [key.gsub(/;$/, ''), '']
    end
  end

  def self.extract_blocks_from_block(lines_array)
    output = {}
    brace_depth = 0
    target_found = false
    block_name = nil

    lines_array.each do |line|
      next if line.strip.empty?
      # fill array with lines to store a new block
      output[block_name] << line if target_found

      brace_depth += 1 if line  =~ /{/
      brace_depth -= 1 if line  =~ /}/

      if brace_depth == 1 && target_found == false
        # found a block
        block_name = line.gsub('{', '').strip
        output[block_name] = []
        target_found = true
      end

      if brace_depth == 0
        unless line.include? '}'
          # 'key value' row found
          key, value = extract_key_value_from_line(line)
          if output.key? key
            if output[key].is_a? Array
              output[key] << value
            else
              # transform to array
              output[key] = [output[key]]
              output[key] << value
            end
          else
            output[key] = value
          end
        end
        target_found = false
      end
    end
    output
  end

  # build the hash (main function)
  def self.format_blocks_to_hash(lines_array, key = nil)
    out = {}
    unless lines_array.class == Array
      return lines_array
    else # array
      return lines_array unless  lines_array.join('').include?('{') || lines_array.join('').include?('}')
    end

    if lines_array.join('').include? '{'
      blocks = extract_blocks_from_block(lines_array)
      blocks.each do |bkey, l_array|
        out[bkey] = format_blocks_to_hash(l_array, bkey)
      end
    else
      lines_array.each do |line|
        unless line.include? '}'
          key, value = extract_key_value_from_line(line)

          if out.key? key
            if out[key].is_a? Array
              out[key] << value
            else
              # transform to array
              out[key] = [out[key]]
              out[key] << value
            end
          else
            out[key] = value
          end
        end
      end
    end
    out
  end
end
