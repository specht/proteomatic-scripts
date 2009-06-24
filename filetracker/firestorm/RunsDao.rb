class RunsDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( run_id, user, title, host ) VALUES ( ?, ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.user, dto.title, dto.host);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET run_id = ?, user = ?, title = ?, host = ? WHERE run_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId, dto.user, dto.title, dto.host, dto.runId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE run_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.runId);
    st.close();
  end

  def findByPrimaryKey(runId);
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " WHERE run_id = ?"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " ORDER BY run_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereRunIdEquals(runId);
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " WHERE run_id = ? ORDER BY run_id"
    st = @my.prepare(sql)
    st.execute(runId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereUserEquals(user);
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " WHERE user = ? ORDER BY user"
    st = @my.prepare(sql)
    st.execute(user)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereTitleEquals(title);
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " WHERE title = ? ORDER BY title"
    st = @my.prepare(sql)
    st.execute(title)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereHostEquals(host);
    sql = "SELECT run_id, user, title, host FROM " + getTableName() + " WHERE host = ? ORDER BY host"
    st = @my.prepare(sql)
    st.execute(host)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Runs.new
      dto.runId = row[0]
      dto.user = row[1]
      dto.title = row[2]
      dto.host = row[3]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "runs"
  end
end
