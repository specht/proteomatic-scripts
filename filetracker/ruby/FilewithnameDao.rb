class FilewithnameDao

  def initialize(my)
    @my = my;
  end

  def insert(dto)
    sql = "INSERT INTO " + getTableName() + " ( filewithname_id, filecontent_id, basename, directory, ctime, mtime ) VALUES ( ?, ?, ?, ?, ?, ? )";
    st = @my.prepare(sql);
    st.execute(dto.filewithnameId, dto.filecontentId, dto.basename, dto.directory, dto.ctime, dto.mtime);
    st.close();
  end

  def update(dto)
    sql = "UPDATE " + getTableName() + " SET filewithname_id = ?, filecontent_id = ?, basename = ?, directory = ?, ctime = ?, mtime = ? WHERE filewithname_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.filewithnameId, dto.filecontentId, dto.basename, dto.directory, dto.ctime, dto.mtime, dto.filewithnameId);
    st.close();
  end

  def delete(dto)
    sql = "DELETE FROM " + getTableName() + " WHERE filewithname_id = ?";
    st = @my.prepare(sql);
    st.execute(dto.filewithnameId);
    st.close();
  end

  def findByPrimaryKey(filewithnameId);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE filewithname_id = ?"
    st = @my.prepare(sql)
    st.execute(filewithnameId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findAll();
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " ORDER BY filewithname_id"
    st = @my.prepare(sql)
    st.execute()
    result = fetchResults(st)
    st.close
    return result
  end

  def findByFilecontents(filecontentId);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE filecontent_id = ?"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereFilewithnameIdEquals(filewithnameId);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE filewithname_id = ? ORDER BY filewithname_id"
    st = @my.prepare(sql)
    st.execute(filewithnameId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereFilecontentIdEquals(filecontentId);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE filecontent_id = ? ORDER BY filecontent_id"
    st = @my.prepare(sql)
    st.execute(filecontentId)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereBasenameEquals(basename);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE basename = ? ORDER BY basename"
    st = @my.prepare(sql)
    st.execute(basename)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereDirectoryEquals(directory);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE directory = ? ORDER BY directory"
    st = @my.prepare(sql)
    st.execute(directory)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereCtimeEquals(ctime);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE ctime = ? ORDER BY ctime"
    st = @my.prepare(sql)
    st.execute(ctime)
    result = fetchResults(st)
    st.close
    return result
  end

  def findWhereMtimeEquals(mtime);
    sql = "SELECT filewithname_id, filecontent_id, basename, directory, ctime, mtime FROM " + getTableName() + " WHERE mtime = ? ORDER BY mtime"
    st = @my.prepare(sql)
    st.execute(mtime)
    result = fetchResults(st)
    st.close
    return result
  end

  def fetchResults(stmt)
    rows = []
    while row = stmt.fetch do
      dto = Filewithname.new
      dto.filewithnameId = row[0]
      dto.filecontentId = row[1]
      dto.basename = row[2]
      dto.directory = row[3]
      dto.ctime = row[4]
      dto.mtime = row[5]
      rows << dto
    end
    return rows
  end

  def getTableName()
    return "filewithname"
  end
end
