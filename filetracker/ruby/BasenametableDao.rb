class BasenametableDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( basename_id, size, basename ) VALUES ( ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.basenameId, dto.size, dto.basename);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET basename_id = ?, size = ?, basename = ? WHERE basename_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.basenameId, dto.size, dto.basename, dto.basenameId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE basename_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.basenameId);
    st.close();
  end

  def findByPrimaryKey(basenameId);
    sql = "SELECT basename_id, size, basename FROM " + getTableName() + " WHERE basename_id = ?"
    st = @my.prepare(sql)
    st.execute(basenameId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT basename_id, size, basename FROM " + getTableName() + " ORDER BY basename_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereBasenameIdEquals(basenameId);
    sql = "SELECT basename_id, size, basename FROM " + getTableName() + " WHERE basename_id = ? ORDER BY basename_id"
    st = @my.prepare(sql)
    st.execute(basenameId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereSizeEquals(size);
    sql = "SELECT basename_id, size, basename FROM " + getTableName() + " WHERE size = ? ORDER BY size"
    st = @my.prepare(sql)
    st.execute(size)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereBasenameEquals(basename);
    sql = "SELECT basename_id, size, basename FROM " + getTableName() + " WHERE basename = ? ORDER BY basename"
    st = @my.prepare(sql)
    st.execute(basename)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Basenametable.new
      dto.basenameId = row[0]
      dto.size = row[1]
      dto.basename = row[2]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "basenametable"
  end
end
