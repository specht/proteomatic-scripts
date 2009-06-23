class FilecontentsDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( filecontent_id, identifier ) VALUES ( ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.filecontentId, dto.identifier);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET filecontent_id = ?, identifier = ? WHERE filecontent_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.filecontentId, dto.identifier, dto.filecontentId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE filecontent_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.filecontentId);
    st.close();
  end

  def findByPrimaryKey(filecontentId);
    sql = "SELECT filecontent_id, identifier FROM " + getTableName() + " WHERE filecontent_id = ?"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT filecontent_id, identifier FROM " + getTableName() + " ORDER BY filecontent_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereFilecontentIdEquals(filecontentId);
    sql = "SELECT filecontent_id, identifier FROM " + getTableName() + " WHERE filecontent_id = ? ORDER BY filecontent_id"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereIdentifierEquals(identifier);
    sql = "SELECT filecontent_id, identifier FROM " + getTableName() + " WHERE identifier = ? ORDER BY identifier"
    st = @my.prepare(sql)
    st.execute(identifier)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Filecontents.new
      dto.filecontentId = row[0]
      dto.identifier = row[1]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "filecontents"
  end
end
