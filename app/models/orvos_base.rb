class OrvosBase < ActiveRecord::Base
  self.abstract_class = true

  def self.columns
    return @columns unless @columns.nil?
    @columns = []
    return @columns if $orvos_api_client.orvos_schema[self.to_s.to_sym].nil?
    $orvos_api_client.orvos_schema[self.to_s.to_sym].each do |coldef|
      k = coldef[:name].to_sym
      if coldef[:type] == coldef[:type].downcase
        @columns << column(k, coldef[:type].to_sym)
      else
        @columns << column(k, :text)
        serialize k, coldef[:type].constantize
      end
      attr_accessible k
    end
    attr_reader :etag
    attr_reader :kind
    @columns
  end
  def self.column(name, sql_type = nil, default = nil, null = true)
    ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end
  def self.find(uuid)
    new($orvos_api_client.api(self, '/' + uuid))
  end
  def self.where(*args)
    OrvosResourceList.new(self).where(*args)
  end
  def self.eager(*args)
    OrvosResourceList.new(self).eager(*args)
  end
  def self.all(*args)
    OrvosResourceList.new(self).all(*args)
  end
  def save
    obdata = {}
    self.class.columns.each do |col|
      obdata[col.name.to_sym] = self.send(col.name.to_sym)
    end
    obdata.delete :id
    obdata.delete :uuid
    postdata = { self.class.to_s.underscore => obdata }
    if etag
      postdata['_method'] = 'PUT'
      resp = $orvos_api_client.api(self.class, '/' + uuid, postdata)
    else
      resp = $orvos_api_client.api(self.class, '', postdata)
    end
    return false if !resp[:etag] || !resp[:uuid]
    @etag = resp[:etag]
    @kind = resp[:kind]
    self.uuid ||= resp[:uuid]
    self
  end
  def save!
    self.save or raise Exception.new("Save failed")
  end
  def initialize(h={})
    @etag = h.delete :etag
    @kind = h.delete :kind
    super
  end
  def metadata(*args)
    o = {}
    o.merge!(args.pop) if args[-1].is_a? Hash
    o[:metadata_class] ||= args.shift
    o[:name] ||= args.shift
    o[:head_kind] ||= args.shift
    o[:tail_kind] = self.kind
    o[:tail] = self.uuid
    if all_metadata
      return all_metadata.select do |m|
        ok = true
        o.each do |k,v|
          if !v.nil?
            test_v = m.send(k)
            if (v.respond_to?(:uuid) ? v.uuid : v.to_s) != (test_v.respond_to?(:uuid) ? test_v.uuid : test_v.to_s)
              ok = false
            end
          end
        end
        ok
      end
    end
    @metadata = $orvos_api_client.api Metadatum, '', { _method: 'GET', where: o, eager: true }
    @metadata = $orvos_api_client.unpack_api_response(@metadata)
  end
  def all_metadata
    return @all_metadata if @all_metadata
    res = $orvos_api_client.api Metadatum, '', {
      _method: 'GET',
      where: {
        tail_kind: self.kind,
        tail: self.uuid
      },
      eager: true
    }
    @all_metadata = $orvos_api_client.unpack_api_response(res)
  end
  def reload
    raise "No such object" if !uuid
    $orvos_api_client.api(self, '/' + uuid).each do |k,v|
      self.instance_variable_set('@' + k.to_s, v)
    end
    @all_metadata = nil
  end
  def dup
    super.forget_uuid!
  end

  protected

  def forget_uuid!
    self.uuid = nil
    @etag = nil
    self
  end
end
