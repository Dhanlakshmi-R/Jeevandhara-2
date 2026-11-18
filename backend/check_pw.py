from app import auth_utils
h = "$2b$12$tMfVFRAdoBWLOyMRiAqaju0aTzc1YEvkoPOzjqbQMaJZuJcIikr5W"
print("wrong:", auth_utils.verify_password("wrong", h))
print("demo:", auth_utils.verify_password("demo-demo-demo", h))