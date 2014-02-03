class ExportsController < ApplicationController

  def show
    # Streaming the response_body

     @filename = "Fairnopoly_export_#{Time.now.strftime("%Y-%d-%m %H:%M:%S")}.csv"
     self.response.headers["Content-Type"] = 'text/csv'
     self.response.headers["Content-Disposition"] = "attachment; filename=#{@filename}"
     self.response.headers["Content-Transfer-Encoding"] = "binary"
     self.response.headers['Last-Modified'] = Time.now.ctime.to_s
     self.response_body = ExportStreamer.new(current_user, params[:kind_of_article])

  end
end