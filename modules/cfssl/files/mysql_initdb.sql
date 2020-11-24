-- https://github.com/cloudflare/cfssl/blob/1.3.0/certdb/mysql/migrations/001_CreateCertificates.sql
DROP TABLE IF EXISTS certificates;
DROP TABLE IF EXISTS ocsp_responses;
CREATE TABLE certificates (
  serial_number            varbinary(128) NOT NULL,
  authority_key_identifier varbinary(128) NOT NULL,
  ca_label                 varbinary(128),
  status                   varbinary(128) NOT NULL,
  reason                   int,
  expiry                   timestamp DEFAULT '0000-00-00 00:00:00',
  revoked_at               timestamp DEFAULT '0000-00-00 00:00:00',
  pem                      varbinary(4096) NOT NULL,
  PRIMARY KEY(serial_number, authority_key_identifier)
);

CREATE TABLE ocsp_responses (
  serial_number            varbinary(128) NOT NULL,
  authority_key_identifier varbinary(128) NOT NULL,
  body                     varbinary(4096) NOT NULL,
  expiry                   timestamp DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY(serial_number, authority_key_identifier)
);
