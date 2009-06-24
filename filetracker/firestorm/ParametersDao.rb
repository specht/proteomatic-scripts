class ParametersDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( parameter_id, key, value, run_id, USING ) VALUES ( ?, ?, ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.parameterId, dto.key, dto.value, dto.runId, dto.using);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET parameter_id = ?, key = ?, value = ?, run_id = ?, USING = ? WHERE parameter_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.parameterId, dto.key, dto.value, dto.runId, dto.using, dto.parameterId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE parameter_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.parameterId);
    st.close();
  end

  def findByPrimaryKey(parameterId);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE parameter_id = ?"
    st = @my.prepare(sql)
    st.execute(parameterId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " ORDER BY parameter_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findByRuns(runId);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE run_id = ?"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereParameterIdEquals(parameterId);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE parameter_id = ? ORDER BY parameter_id"
    st = @my.prepare(sql)
    st.execute(parameterId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereKeyEquals(key);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE key = ? ORDER BY key"
    st = @my.prepare(sql)
    st.execute(key)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereValueEquals(value);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE value = ? ORDER BY value"
    st = @my.prepare(sql)
    st.execute(value)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereRunIdEquals(runId);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE run_id = ? ORDER BY run_id"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereUsingEquals(using);
    sql = "SELECT parameter_id, key, value, run_id, USING FROM " + getTableName() + " WHERE USING = ? ORDER BY USING"
    st = @my.prepare(sql)
    st.execute(using)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Parameters.new
      dto.parameterId = row[0]
      dto.key = row[1]
      dto.value = row[2]
      dto.runId = row[3]
      dto.using = row[4]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "parameters"
  end
end
