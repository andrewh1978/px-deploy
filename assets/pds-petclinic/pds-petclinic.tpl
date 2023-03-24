apiVersion: v1
kind: Secret
metadata:
  name: petclinic-db
  namespace: (NAMESPACE)
type: Opaque
stringData:
    PG_URL: 'jdbc:postgresql://(VIP):(PORT)/pds'
    PG_USERNAME: 'pds'
---
apiVersion: v1
kind: Service
metadata:
  name: petclinic
  labels:
    app: petclinic
  namespace: (NAMESPACE)
spec:
  type: NodePort
  ports:
  - name: http
    protocol: TCP
    port: 8080
    targetPort: 8080
    nodePort: 30333
  selector:
    app: petclinic
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic
  labels:
    app: petclinic
  namespace: (NAMESPACE)
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petclinic
  template:
    metadata:
      labels:
        app: petclinic
    spec:
      schedulerName: stork
      containers:
      - name: petclinic
        image: danpaul81/spring-petclinic:2.7.3
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            port: 8080
            path: /actuator/health/liveness
          initialDelaySeconds: 90
          periodSeconds: 5
        readinessProbe:
          httpGet:
            port: 8080
            path: /actuator/health/readiness
          initialDelaySeconds: 15
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: 'postgres'
        - name: SPRING_DATASOURCE_URL
          valueFrom:
            secretKeyRef:
              name: petclinic-db  
              key: PG_URL
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: petclinic-db
              key: PG_USERNAME
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: (CREDS)
              key: password

