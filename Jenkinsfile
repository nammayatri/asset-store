def allowedBranches = ["main"]

def uploadedFiles = ""

def setupAWS(env, isProd){
  if (isProd) {
      env.ASSUMED_ROLE = "arn:aws:iam::980691203742:role/ny-hyper-sdk-jenkins"
      env.S3_BUCKET = "hyper-sdk-assets-prod-buffer-ny"
      env.CF_DISTRIBUTION_ID = "E2ECP49Q9319IB"
  } else {
      env.S3_BUCKET = "beta-moving-tech-assets"
      env.CF_DISTRIBUTION_ID = "E2UYZKLVHOVJDR"
  }

  if (isProd) {
    env.AWS_STS_RESPONSE = """${sh(
            returnStdout: true,
            script: '''
            set +x;
            unset AWS_SECRET_ACCESS_KEY;
            unset AWS_SESSION_TOKEN;
            unset AWS_ACCESS_KEY_ID;
            aws sts assume-role --role-arn ${ASSUMED_ROLE} --role-session-name s3-bucket-access;
            '''
        )}"""
    env.AWS_SECRET_ACCESS_KEY = """${sh(
            returnStdout: true,
            script: '''
            set +x;
            echo ${AWS_STS_RESPONSE} | jq '.Credentials.SecretAccessKey' | xargs | tr -d '\n';
            '''
        )}"""
    env.AWS_SESSION_TOKEN = """${sh(
            returnStdout: true,
            script: '''
            set +x;
            echo ${AWS_STS_RESPONSE} | jq '.Credentials.SessionToken' | xargs | tr -d '\n';
            '''
        )}"""
    env.AWS_ACCESS_KEY_ID = """${sh(
            returnStdout: true,
            script: '''
            set +x;
            echo ${AWS_STS_RESPONSE} | jq '.Credentials.AccessKeyId' | xargs | tr -d '\n';
            '''
        )}"""
  }
}

pipeline {
  agent {
      kubernetes {
            label 'mobility-agent'
      }
  }

  triggers {
      pollSCM('H/10 * * * *')
  }

  options {
      disableConcurrentBuilds()
  }

  environment {
        GIT_AUTHOR_NAME = "Jenkins"
        GIT_COMMITTER_NAME = "Jenkins"
        AWS_REGION = "ap-south-1"
        SKIP_BUILD = "false"
    }

  stages {

    stage('Check Commit For Skip CI') {
        steps {
            script {
                def commitMsg = sh(
                    returnStdout: true,
                    script: 'git log -1 --pretty=%B'
                ).trim()

                echo "Latest commit message: ${commitMsg}"

                if (commitMsg.contains('[skip ci]')) {
                    echo "Detected bot commit with [skip ci] — skipping build to avoid infinite trigger loop."
                    env.SKIP_BUILD = "true"
                    currentBuild.result = 'SUCCESS'
                } else {
                    env.SKIP_BUILD = "false"
                }
            }
        }
    }

    stage('Getting Commit Id of Last Push') {
        when {
            expression { return env.SKIP_BUILD != 'true' }
        }
        steps {
            script {
                echo "bob started building"

                env.LAST_PUSH = """${sh(
                  returnStdout: true,
                  script: '''
                  set +x;
                  cat s3LastCommitPush.txt
                  '''
                )}"""
                
                echo "last push commit Id ${env.LAST_PUSH}"
              }
          }
      }

    stage('Setup AWS') {
        when {
            expression { return env.SKIP_BUILD != 'true' }
        }
        steps {
            script {
                // Determine if this is a production deployment
                def isProd = (env.BRANCH_NAME == "main")
                
                // Setup AWS credentials via role assumption
                setupAWS(env, isProd)
                
                // Export AWS credentials for use in subsequent stages
                if (isProd) {
                    sh """
                        export AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=${env.AWS_SESSION_TOKEN}
                        export AWS_REGION=${env.AWS_REGION}
                        echo "AWS credentials configured via role assumption"
                    """
                }
                
                echo "S3 Bucket: ${env.S3_BUCKET}"
                echo "CloudFront Distribution ID: ${env.CF_DISTRIBUTION_ID}"
            }
        }
    }

    stage('Uploading Assets') {
        when {
            expression { return env.SKIP_BUILD != 'true' }
        }
        steps {
            script {
                // Determine if this is a production deployment
                def isProd = (env.BRANCH_NAME == "main")
                
                def changedFiles = """${sh(
                    returnStdout: true,
                    script: '''
                    set +x;
                    git diff ${LAST_PUSH} ${GIT_COMMIT} --name-only --diff-filter=AMR;
                    '''
                  )}""".trim().split("\n")

                for (file in changedFiles) {
                    def contentType = ""
                    if (file == 'package.json') {
                      continue;
                    } else if (file ==~ '.*\\.mp4$') {
                      contentType = "video/mp4"
                    } else if (file ==~ '.*\\.mp3$') {
                      contentType = "audio/mpeg"
                    } else if (file ==~ '.*\\.png$') {
                      contentType = "image/png"
                    } else if (file ==~ '.*\\.gif$') {
                      contentType = "image/gif"
                    } else if (file ==~ '.*\\.ttf$') {
                      contentType = "application/font-sfnt"
                    } else if (file ==~ '.*\\.json$') {
                      contentType = "application/json"
                    } else if (file ==~ '.*\\.svg$') {
                      contentType = "image/svg+xml"
                    } else if (file ==~ '.*\\.jsa$') {
                      contentType = "binary/octet-stream"
                    } else if (file ==~ '.*\\.pdf$') {
                      contentType = "application/pdf"
                    } else if (file ==~ '.*\\.html$') {
                      contentType = "text/html"
                    } else if (file ==~ '.*\\.webp$') {
                      contentType = "image/webp"
                    } else if (file ==~ '.*\\.lottie$') {
                      contentType = "binary/octet-stream"
                    } else {
                      continue
                    }

                    echo "bob is pushing file ${file} to s3 bucket ${env.S3_BUCKET}"

                    // Use the bucket from setupAWS
                    def s3Path = "s3://${env.S3_BUCKET}/${file}"

                    sh "chmod +x ./push.sh"
                    
                    // Export AWS credentials and bucket info for push.sh script
                    if (isProd) {
                        sh """
                            export AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY}
                            export AWS_SESSION_TOKEN=${env.AWS_SESSION_TOKEN}
                            export AWS_REGION=${env.AWS_REGION}
                            export S3_BUCKET=${env.S3_BUCKET}
                            export CF_DISTRIBUTION_ID=${env.CF_DISTRIBUTION_ID}
                            ./push.sh ${file} --no-compress --no-resize --no-check
                        """
                    } else {
                        sh """
                            export S3_BUCKET=${env.S3_BUCKET}
                            export CF_DISTRIBUTION_ID=${env.CF_DISTRIBUTION_ID}
                            ./push.sh ${file} --no-compress --no-resize --no-check
                        """
                    }

                    uploadedFiles += "\n${file}"
                  }
              }
          }
      }

    stage('Notify Xyne') {
        when {
            expression { return env.SKIP_BUILD != 'true' && uploadedFiles != '' }
        }
        steps {
            script {
                withCredentials([
                    string(credentialsId: 'XYNE_BOT_TOKEN', variable: 'XYNE_BOT_TOKEN'),
                    string(credentialsId: 'XYNE_CHANNEL', variable: 'XYNE_CHANNEL')
                ]) {
                    def fileLines = uploadedFiles.trim().split("\n").collect { "• ${it}" }.join("\\n")
                    def commitUrl = "https://github.com/nammayatri/asset-store/commit/${env.GIT_COMMIT}"
                    def messageText = "*Assets pushed to S3*\\n*Bucket:* ${env.S3_BUCKET}\\n*Commit:* ${commitUrl}\\n*Files:*\\n${fileLines}"

                    def payload = """{
                        "channel": "${'$'}XYNE_CHANNEL",
                        "text": "Assets pushed to S3",
                        "attachments": [
                            {
                                "color": "#71717a",
                                "blocks": [
                                    { "type": "section", "text": { "type": "mrkdwn", "text": "${messageText}" } }
                                ]
                            }
                        ]
                    }"""

                    writeFile file: 'xyne-payload.json', text: payload

                    def notifyStatus = sh(
                        returnStatus: true,
                        script: '''
                        set +x;
                        curl -s -X POST "https://spaces.xyne.juspay.net/api/apps/slack/chat.postMessage" \
                            -H "Authorization: Bearer ${XYNE_BOT_TOKEN}" \
                            -H "Content-Type: application/json; charset=utf-8" \
                            -d @xyne-payload.json
                        '''
                    )

                    sh "rm -f xyne-payload.json"

                    if (notifyStatus != 0) {
                        echo "Xyne notification failed (exit ${notifyStatus}) — not failing the build since assets were already uploaded."
                    }
                }
            }
        }
    }

    stage('Updating S3 Push Record') {
        when {
            expression { return env.SKIP_BUILD != 'true' }
        }
        steps {
            script {
                env.SUMMARY = "Files Uploaded: ${uploadedFiles == '' ? 'NA' : uploadedFiles}"
                
                def branchName = 'main'
                def commitMessage = "[skip ci] updating s3LastCommitPush"
                
                sh "git config user.email 'namma.yatri.jenkins@gmail.com'"
                sh "git config user.name 'ny-jenkins'"
                
                sh "git remote set-url origin git@github.com:nammayatri/asset-store.git"
                sh "git fetch origin ${branchName}"
                sh "git checkout -B ${branchName} origin/${branchName}"
                
                sh "echo ${GIT_COMMIT} > s3LastCommitPush.txt"
                sh "git add s3LastCommitPush.txt"
                
                sh "git commit -m \"${commitMessage}\""
                sh "git push"

                echo "${SUMMARY}"

                echo "bob builded successfully 😎"
              }
          }
      }

  }
}
