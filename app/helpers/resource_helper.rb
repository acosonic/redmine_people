module ResourceHelper

  def csv_content(column, issue)
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, issue, value)
    case value.class.name
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Float'
      sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
    when 'IssueRelation'
      other = value.other_issue(issue)
      l(value.label_for(issue)) + " ##{other.id}"
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    else
      value.to_s
    end
  end

  def query_to_csv(items, query, options={})
    encoding = l(:general_csv_encoding)
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # csv lines
      items.each do |item|
        csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(csv_content(c, item), encoding) }
      end
    end
    export
  end

end
