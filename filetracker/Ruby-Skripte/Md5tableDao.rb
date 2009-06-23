class Md5tableDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( md5_id, size, md5 ) VALUES ( ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.md5Id, dto.size, dto.md5);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET md5_id = ?, size = ?, md5 = ? WHERE md5_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.md5Id, dto.size, dto.md5, dto.md5Id);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE md5_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.md5Id);
    st.close();
  end

  def findByPrimaryKey(md5Id);
    sql = "SELECT md5_id, size, md5 FROM " + getTableName() + " WHERE md5_id = ?"
    st = @my.prepare(sql)
    st.execute(md5Id)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT md5_id, size, md5 FROM " + getTableName() + " ORDER BY md5_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereMd5IdEquals(md5Id);
    sql = "SELECT md5_id, size, md5 FROM " + getTableName() + " WHERE md5_id = ? ORDER BY md5_id"
    st = @my.prepare(sql)
    st.execute(md5Id)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereSizeEquals(size);
    sql = "SELECT md5_id, size, md5 FROM " + getTableName() + " WHERE size = ? ORDER BY size"
    st = @my.prepare(sql)
    st.execute(size)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereMd5Equals(md5);
    sql = "SELECT md5_id, size, md5 FROM " + getTableName() + " WHERE md5 = ? ORDER BY md5"
    st = @my.prepare(sql)
    st.execute(md5)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Md5table.new
      dto.md5Id = row[0]
      dto.size = row[1]
      dto.md5 = row[2]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "md5table"
  end
end
