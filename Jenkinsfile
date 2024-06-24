def allowedBranches = ["main"]

def uploadedFiles = ""

pipeline {
  agent {
      kubernetes {
            label 'dind-agent'
      }
  }
  environment {
        GIT_AUTHOR_NAME = "Jenkins"
        GIT_COMMITTER_NAME = "Jenkins"
    }

  stages {

    stage('Getting Commit Id of Last Push') {
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

    stage('Uploading Asstes') {
        steps {
            script {
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
                    }
                     else {
                      continue
                    }

                    echo "bob is pushing file ${file} to s3"

                    def s3Path = "s3://beckn-frontend-assets/${file}"

                    sh "chmod +x ./push.sh"
                    sh ("./push.sh ${file} --no-compress --no-resize --no-check")

                    uploadedFiles += "\n${file}"
                  }
              }
          }
      }

    stage('Updating S3 Push Record') {
        steps {
            script {
                env.SUMMARY = "Files Uploaded: ${uploadedFiles == '' ? 'NA' : uploadedFiles}"
                
                def branchName = 'main'
                def commitMessage = "[skip ci] updating s3LastCommitPush"
                
                sh "git config user.email 'namma.yatri.jenkins@gmail.com'"
                sh "git config user.name 'ny-jenkins'"
                
                sh "git remote set-url origin git@github.com:nammayatri/asset-store.git"
                sh "git checkout ${branchName}"
                
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
