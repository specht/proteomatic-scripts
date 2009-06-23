class RunParametersDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( run_id, parameter_id ) VALUES ( ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.parameterId);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET run_id = ?, parameter_id = ? WHERE run_id = ? AND parameter_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.parameterId, dto.runId, dto.parameterId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE run_id = ? AND parameter_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.parameterId);
    st.close();
  end

  def findByPrimaryKey(runId, parameterId);
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " WHERE run_id = ? AND parameter_id = ?"
    st = @my.prepare(sql)
    st.execute(runId, parameterId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " ORDER BY run_id, parameter_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findByRuns(runId);
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " WHERE run_id = ?"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findByParameters(parameterId);
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " WHERE parameter_id = ?"
    st = @my.prepare(sql)
    st.execute(parameterId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereRunIdEquals(runId);
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " WHERE run_id = ? ORDER BY run_id"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereParameterIdEquals(parameterId);
    sql = "SELECT run_id, parameter_id FROM " + getTableName() + " WHERE parameter_id = ? ORDER BY parameter_id"
    st = @my.prepare(sql)
    st.execute(parameterId)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = RunParameters.new
      dto.runId = row[0]
      dto.parameterId = row[1]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "run_parameters"
  end
end
