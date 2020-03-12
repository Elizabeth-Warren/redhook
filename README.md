# Redhook

Redhook is a generic webhook interface for landing data in [Kinesis Firehose](https://aws.amazon.com/kinesis/data-firehose/). On Elizabeth Warren's presidential campaign, Redhook was responsible for ingesting real-time data delivered to the campaign via webhooks and forwarding those data to [Redshift](https://aws.amazon.com/redshift/). We used [Civis](https://www.civisanalytics.com/)'s data platform on the campaign so Civis owned and managed the AWS account hosting our Redshift cluster. While you cannot configure a cross-account Kinesis Firehose in the AWS Console (yet), you can setup cross-account Firehoses (as we did here).

During the campaign, Redhook was responsible for delivering all financial data and web analytics to the data teams. It operated at a near-zero cost and experienced no downtime -- though data delivery was delayed on occassion due to upstream problems.

The code and configuration here is simple because it solves a simple problem: moving some data around. Our intention in open sourcing it is to demonstrate that some problems campaigns face do not require vendor tools and are solved reasonably effectively and efficiently with a tiny bit of code.

## Installation

    pipenv install -d
    npm install -g serverless@1.51.0
    npm install

## Deploy

And example `serverless.yml` is provided here. The production configuration was somewhat more complicated but not particularly so.

If a domain does not yet exist for your application stage

    sls create_domain --stage <your stage>

To deploy the code

    sls deploy --stage <your stage>

## Infrastructure

Sample [Terraform](https://www.terraform.io/) modules are included here that could be modified to stand-up the infrastructure required to operate Redhook. High-level, it needs a Kinesis Firehose for each table to which you want to write. We shared configuration between the infrastructure we managed with Terraform and the lambdas we deployed with [serverless](https://serverless.com/). The configuration defined in `serverless.example.yml` assumes that SSM parameters are named as they are in `infrastructure/`.

## API Keys

Apis marked as private in `serverless.yml` require an api key. The `apiKeys` block in the provider definition in `serverless.yml` defines the set of API keys that get generated automatically. If the endpoint is marked as private, one of those API keys must be used as the `x-api-key` header to send data to the webhook.

## Scripts

- `bin/railroad`: Fire sample data from a new-line delimited json file at your api

- `bin/transform-event`: Apply the given transformation to a sample event in some file to see what the transformation does to it
