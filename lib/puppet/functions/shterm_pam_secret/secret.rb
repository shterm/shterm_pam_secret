require 'logger'
require 'open3'
Puppet::Functions.create_function(:'shterm_pam_appmgr::secret') do

  dispatch :secret do
    param 'Hash', :pwdAdminInfo
    param 'String', :fullLogFileName # optional
    return_type 'Hash'
  end

  def secret(pwdAdminInfo, fullLogFileName)
    @pwdAdminInfo = pwdAdminInfo
    if fullLogFileName == ""
      @logger = Logger.new(STDOUT)
    else
      @logger = Logger.new(fullLogFileName)
    end

    @logger.info("Retrieve credential with the following query:")

    @clipasswordsdk_cmd = 'll'

    @query = "";
    queryinfo = @pwdAdminInfo['query']
    appid = @pwdAdminInfo['appid']

    unless appid or queryinfo
        abort 'query or appid info is needed'
    end
    infoMap = resolve(queryinfo)
    query_params = self.analyize_query_params(query)
    account_name = infoMap["username"]
    resouce_name = infoMap["resourceName"] 
    request_reason = infoMap["reason"] 
    connect_port = infoMap["connectPort"] 
    file = infoMap["credentialfile"] 
    @cliPath = ENV['SHTERMAPPMGRCLI'] || '/usr/local/shterm/shterm-appmgr/plugins/pwdlibcli'
    @fullCmd = "#{cliPath} -a #{appid}"
    if account_name
        @fullCmd = "#{fullCmd} -a #{account_name}"
    end
    if resouce_name
        @fullCmd = "#{fullCmd} -r #{resouce_name}"
    end
    if request_reason
        @fullCmd = "#{fullCmd} -R \"#{request_reason}\""
    end
    if connect_port
        @fullCmd = "#{fullCmd} -p #{connect_port}"
    end
    if file
        @fullCmd = "#{fullCmd} -p \"#{file}\""
    end
    result = Hash.new
    begin
      @logger.info("To execute = " + @fullCmd)
      Open3.popen3(@fullCmd) do |stdin, stdout, stderr, wait_thr|
        @logger.info("****")
        exit_status = wait_thr.value
        unless exit_status.success?
          error_msg = "#{@fullCmd}\n"
          stderr.each_line do |line|
            error_msg = "#{error_msg}\n#{line}"
          end
          abort error_msg
        end
        result = getexecResult(stdout, @fullCmd)
      end
      @logger.debug(" exec #{@fullCmd} success")
      return result
    rescue Exception => e
      @logger.error("GetPass() : Got Exception on call to GetPassword :" + e.message )
      raise e
    end
  end

  def getexecResult(stdout, cmd)
    result = Hash.new
    line = stdout.gets
    resultItem = line.split(':')
    if resultItem.length != 2
      abort "exec #{cmd} the first line is not match result #{line}"
    result[resultItem[0]] = resultItem[1]  
    line = stdout.gets
    resultItem = line.split(':')
    if resultItem.length != 2
      abort "exec #{cmd} the second line is not match result #{line}"
    result[resultItem[0]] = resultItem[1]   
    return result
  end  

  def resolve(query)
    value = query.split(';')
    result = Hash.new 
    value.each  do |item|
      attrKV = item.split('=')
      if attrKV.length == 2
        result[attrKV[0]] = attrKV[1]
      end
    end
    return result
  end  
end
