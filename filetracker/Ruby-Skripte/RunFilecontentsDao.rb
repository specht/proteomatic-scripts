class RunFilecontentsDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( run_id, filecontent_id, input_file ) VALUES ( ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.filecontentId, dto.inputFile);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET run_id = ?, filecontent_id = ?, input_file = ? WHERE run_id = ? AND filecontent_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.filecontentId, dto.inputFile, dto.runId, dto.filecontentId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE run_id = ? AND filecontent_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.filecontentId);
    st.close();
  end

  def findByPrimaryKey(runId, filecontentId);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE run_id = ? AND filecontent_id = ?"
    st = @my.prepare(sql)
    st.execute(runId, filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " ORDER BY run_id, filecontent_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findByRuns(runId);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE run_id = ?"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findByFilecontents(filecontentId);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE filecontent_id = ?"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereRunIdEquals(runId);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE run_id = ? ORDER BY run_id"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereFilecontentIdEquals(filecontentId);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE filecontent_id = ? ORDER BY filecontent_id"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereInputFileEquals(inputFile);
    sql = "SELECT run_id, filecontent_id, input_file FROM " + getTableName() + " WHERE input_file = ? ORDER BY input_file"
    st = @my.prepare(sql)
    st.execute(inputFile)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = RunFilecontents.new
      dto.runId = row[0]
      dto.filecontentId = row[1]
      dto.inputFile = row[2]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "run_filecontents"
  end
end
