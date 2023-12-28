import os
from threading import Thread
from time import sleep
from requests import get


def request_cluster_1(url, content_type):
    
    print("Cluster 1: Sending 1000 requests to: " + url)
    for _ in range(1000):
      get(url,headers=content_type)


def request_cluster_2(url, content_type):
  
    print("Cluster 2: Sending 500 requests to: " + url)
    for _ in range(500):
      get(url,headers=content_type)

    print("Sleeping for 60 sec...\n") 
    sleep(60)
    
    print("Sending 1000 requests to: " + url)
    for _ in range(1000):
      get(url, headers=content_type)
      
if __name__ == "__main__":
  print("Waiting 30 seconds for the instances to be initialized...\n")
  sleep(30)
  
  load_balancer_url = "http://" + os.environ.get('load_balancer_url')
  headers = {"content-type": "application/json"}
  
  cluster_1 = Thread(target=request_cluster_1, args=(load_balancer_url + "/cluster1", headers))
  cluster_2 = Thread(target=request_cluster_2, args=(load_balancer_url + "/cluster2", headers))
  
  cluster_1.start()
  print("Cluster 1 started\n")
  
  cluster_2.start()  
  print ("Cluser 2 started\n")
  
  cluster_1.join()
  print("Cluster 1 joined\n")
   
  cluster_2.join()
  print("Cluster 2 joined\n")
  
  print("Done!\n")
      
      

      
