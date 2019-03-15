# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form4142Processor
      attr_reader :pdf_path, :request_body

      FORM_ID = '21-4142'
      FOREIGN_POSTALCODE = '00000'

      def initialize(submission, jid)
        @submission = submission
        @pdf_path = generate_stamp_pdf
        @request_body = {
          'document' => to_faraday_upload(@pdf_path),
          'metadata' => generate_metadata(@pdf_path, jid)
        }
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "FDC Reviewed - Vets.gov Submission" at the top of each page
      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(
          @submission.form[Form526Submission::FORM_4142], @submission.submitted_claim_id, FORM_ID
        )
        stamped_path = CentralMail::DatestampPdf.new(pdf).run(text: 'VA.gov', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: true
        )
      end

      private

      def to_faraday_upload(pdf_path)
        Faraday::UploadIO.new(
          pdf_path,
          Mime[:pdf].to_s
        )
      end

      def get_hash_and_pages(file_path)
        {
          hash: Digest::SHA256.file(file_path).hexdigest,
          pages: PDF::Reader.new(file_path).pages.size
        }
      end

      def generate_metadata(pdf_path, jid)
        form = @submission.form[Form526Submission::FORM_4142]
        veteran_full_name = form['veteranFullName']
        address = form['veteranAddress']

        {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          'receiveDt' => received_date,
          'uuid' => jid,
          'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
          'source' => 'VA Forms Group B',
          'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
          'numberAttachments' => 0,
          'docType' => FORM_ID,
          'numberPages' => PDF::Reader.new(pdf_path).pages.size
        }.to_json
      end

      def received_date
        date = SavedClaim::DisabilityCompensation.find(@submission.saved_claim_id).created_at
        date = date.in_time_zone('Central Time (US & Canada)')
        date.strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
